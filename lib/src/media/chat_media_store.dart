import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/cache/chat_cache.dart';
import 'package:flutter_chat_pro/src/media/media_entry.dart';
import 'package:flutter_chat_pro/src/platform/io.dart';
import 'package:http/http.dart' as http;
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Exports a stored file, for example to the photo gallery. Returns whether
/// it was saved.
typedef SaveMediaCallback =
    Future<bool> Function(File file, {String? name, String? mimeType});

/// The system "save as" dialog; `FilePicker.saveFile` by default.
typedef SaveDialog =
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
    });

/// Keeps media files on disk so each one downloads at most once (D11).
///
/// Files live in the app support directory, one folder per user, indexed in
/// the chat cache by remote URL. The user's own uploads are copied in
/// ([adopt]) and never download. The least recently used files are evicted
/// past [maxBytes]. On the web there is no file system: [isSupported] is
/// false and widgets load URLs directly (the browser caches them).
class ChatMediaStore {
  ChatMediaStore({
    required this.userId,
    required this._cache,
    http.Client? client,
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? clock,
    this.maxBytes,
    this.onSave,
    SaveDialog? saveDialog,
  }) : _client = client,
       _ownsClient = client == null,
       _rootDirectory = rootDirectory ?? getApplicationSupportDirectory,
       _clock = clock ?? _utcNow,
       _saveDialog = saveDialog ?? _filePickerSave;

  final String userId;
  final ChatCache _cache;
  http.Client? _client;
  final bool _ownsClient;
  final Future<Directory> Function() _rootDirectory;
  final DateTime Function() _clock;
  final SaveDialog _saveDialog;

  /// Evict least recently used files beyond this size. Null keeps all.
  final int? maxBytes;

  /// Replaces the save dialog in [save].
  final SaveMediaCallback? onSave;

  static const _uuid = Uuid();

  final _downloads = <String, Future<File>>{};
  final _progress = <String, ValueNotifier<double?>>{};
  final _known = <String, File>{};
  Future<Directory>? _directory;

  /// False on the web.
  bool get isSupported => !kIsWeb;

  /// The stored file for [remoteUrl] if this session already resolved it;
  /// lets widgets show it on the first frame.
  File? peek(String remoteUrl) => _known[remoteUrl];

  /// The stored copy of [remoteUrl], or null.
  Future<File?> file(String remoteUrl) async {
    if (!isSupported || !_cache.isOpen) return null;
    final entry = await _cache.mediaEntry(remoteUrl);
    if (entry == null) return null;
    final file = File(p.join((await _dir()).path, entry.fileName));
    if (!file.existsSync()) {
      _known.remove(remoteUrl);
      await _cache.removeMedia([remoteUrl]);
      return null;
    }
    _known[remoteUrl] = file;
    await _cache.touchMedia(remoteUrl, _clock());
    return file;
  }

  /// The stored copy of [remoteUrl], downloading it first when needed.
  /// Concurrent calls share one download.
  ///
  /// Throws `NetworkFailure`, `ServerFailure` or `StorageFailure`.
  Future<File> fetch(
    String remoteUrl, {
    void Function(double fraction)? onProgress,
  }) async {
    if (!isSupported) throw UnsupportedError('No file system on the web');
    final stored = await file(remoteUrl);
    if (stored != null) return stored;
    final running = _downloads[remoteUrl];
    if (running != null) return await running;
    final download = _download(remoteUrl, onProgress);
    _downloads[remoteUrl] = download;
    try {
      return await download;
    } finally {
      unawaited(_downloads.remove(remoteUrl));
    }
  }

  /// Download fraction 0..1 while [remoteUrl] downloads, otherwise null.
  ValueListenable<double?> downloadProgress(String remoteUrl) =>
      _progress.putIfAbsent(remoteUrl, () => ValueNotifier(null));

  /// Copies the user's own file at [localPath] in as [remoteUrl], so it is
  /// never downloaded. Missing files are ignored.
  Future<void> adopt(
    String localPath,
    String remoteUrl, {
    String? mimeType,
  }) async {
    if (!isSupported || !_cache.isOpen) return;
    final source = File(localPath);
    if (!source.existsSync()) return;
    final name = _fileName(remoteUrl, mimeType, fallbackPath: localPath);
    final File copy;
    try {
      copy = await source.copy(p.join((await _dir()).path, name));
    } on FileSystemException catch (e, s) {
      throw StorageFailure(cause: e, trace: s);
    }
    await _cache.putMedia(
      MediaEntry(
        remoteUrl: remoteUrl,
        fileName: name,
        size: await copy.length(),
        mimeType: mimeType,
        lastAccess: _clock(),
      ),
    );
    _known[remoteUrl] = copy;
    await _enforceLimit();
  }

  /// Exports [remoteUrl] (downloading it first when needed) through
  /// [onSave], else the system save dialog. Returns whether it was saved.
  Future<bool> save(String remoteUrl, {String? name, String? mimeType}) async {
    final file = await fetch(remoteUrl);
    final entry = await _cache.mediaEntry(remoteUrl);
    final type = mimeType ?? entry?.mimeType;
    final fileName = name ?? _displayName(remoteUrl, file);
    final override = onSave;
    if (override != null) {
      return await override(file, name: fileName, mimeType: type);
    }
    final uri = await _saveDialog(
      fileName: fileName,
      bytes: await file.readAsBytes(),
      mimeType: type ?? 'application/octet-stream',
    );
    return uri != null;
  }

  /// Deletes the least recently used files until the total is at most
  /// [maxBytes]. Files that are downloading stay.
  Future<void> trim({required int maxBytes}) async {
    if (!isSupported || !_cache.isOpen) return;
    final entries = await _cache.mediaEntries();
    var total = entries.fold<int>(0, (sum, e) => sum + e.size);
    if (total <= maxBytes) return;
    final dir = await _dir();
    final removed = <String>[];
    for (final entry in entries) {
      if (total <= maxBytes) break;
      if (_downloads.containsKey(entry.remoteUrl)) continue;
      final file = File(p.join(dir.path, entry.fileName));
      if (file.existsSync()) await file.delete();
      _known.remove(entry.remoteUrl);
      removed.add(entry.remoteUrl);
      total -= entry.size;
    }
    await _cache.removeMedia(removed);
  }

  /// Deletes every stored file of the user and the index.
  Future<void> clear() async {
    if (!isSupported) return;
    _known.clear();
    Directory? dir;
    try {
      dir = await _dir();
    } on Exception {
      // No app directory (for example in tests without path_provider):
      // nothing was stored there.
    }
    _directory = null;
    if (dir != null && dir.existsSync()) await dir.delete(recursive: true);
    if (_cache.isOpen) {
      final entries = await _cache.mediaEntries();
      await _cache.removeMedia([for (final e in entries) e.remoteUrl]);
    }
  }

  /// Releases the HTTP client; the store keeps working and opens a new one
  /// when needed.
  void close() {
    if (_ownsClient) {
      _client?.close();
      _client = null;
    }
  }

  Future<File> _download(
    String remoteUrl,
    void Function(double fraction)? onProgress,
  ) async {
    final progress = _progress.putIfAbsent(remoteUrl, () => ValueNotifier(null))
      ..value = 0;
    final client = _client ??= http.Client();
    File? part;
    try {
      final http.StreamedResponse response;
      try {
        response = await client.send(http.Request('GET', Uri.parse(remoteUrl)));
      } on Exception catch (e, s) {
        throw NetworkFailure(cause: e, trace: s);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerFailure(status: response.statusCode);
      }
      final mimeType = response.headers['content-type']?.split(';').first;
      final name = _fileName(remoteUrl, mimeType);
      final dir = await _dir();
      part = File(p.join(dir.path, '$name.part'));
      final total = response.contentLength;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            final fraction = (received / total).clamp(0.0, 1.0);
            progress.value = fraction;
            onProgress?.call(fraction);
          }
        }
      } on Exception catch (e, s) {
        throw NetworkFailure(cause: e, trace: s);
      } finally {
        await sink.close();
      }
      final file = await part.rename(p.join(dir.path, name));
      part = null;
      await _cache.putMedia(
        MediaEntry(
          remoteUrl: remoteUrl,
          fileName: name,
          size: received,
          mimeType: mimeType,
          lastAccess: _clock(),
        ),
      );
      _known[remoteUrl] = file;
      onProgress?.call(1);
      await _enforceLimit();
      return file;
    } on FileSystemException catch (e, s) {
      throw StorageFailure(cause: e, trace: s);
    } finally {
      progress.value = null;
      final leftover = part;
      if (leftover != null && leftover.existsSync()) await leftover.delete();
    }
  }

  Future<void> _enforceLimit() async {
    final limit = maxBytes;
    if (limit != null) await trim(maxBytes: limit);
  }

  Future<Directory> _dir() => _directory ??= () async {
    final root = await _rootDirectory();
    final dir = Directory(
      p.join(
        root.path,
        'flutter_chat_pro',
        'media',
        _uuid.v5(Namespace.url.value, userId),
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }();

  /// A stable, file-system-safe name for [remoteUrl], keeping its extension.
  static String _fileName(
    String remoteUrl,
    String? mimeType, {
    String? fallbackPath,
  }) {
    final base = _uuid.v5(Namespace.url.value, remoteUrl);
    final ext =
        _extensionOf(Uri.tryParse(remoteUrl)?.path) ??
        _extensionOf(fallbackPath) ??
        _mimeExtensions[mimeType] ??
        '';
    return '$base$ext';
  }

  static String? _extensionOf(String? path) {
    if (path == null) return null;
    final ext = p.extension(path).toLowerCase();
    if (ext.length < 2 || ext.length > 6) return null;
    return RegExp(r'^\.[a-z0-9]+$').hasMatch(ext) ? ext : null;
  }

  static String _displayName(String remoteUrl, File file) {
    final segments = Uri.tryParse(remoteUrl)?.pathSegments ?? const [];
    final last = segments.isEmpty ? '' : segments.last;
    return last.isEmpty ? p.basename(file.path) : Uri.decodeComponent(last);
  }

  static const _mimeExtensions = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/heic': '.heic',
    'video/mp4': '.mp4',
    'video/quicktime': '.mov',
    'audio/mp4': '.m4a',
    'audio/aac': '.aac',
    'audio/mpeg': '.mp3',
    'audio/ogg': '.ogg',
    'audio/wav': '.wav',
    'application/pdf': '.pdf',
  };

  static Future<Uri?> _filePickerSave({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
