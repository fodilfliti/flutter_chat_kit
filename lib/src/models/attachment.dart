import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

enum AttachmentKind { image, video, audio, file }

/// A media or file payload of a message.
///
/// While uploading, [localPath] is set and [remoteUrl] is null. [width] and
/// [height] let the UI reserve space before the image loads.
@immutable
class Attachment {
  const Attachment({
    required this.mimeType,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.size,
    this.width,
    this.height,
    this.duration,
    this.name,
  });

  /// Reads an attachment object, or a bare URL string.
  ///
  /// Without a mime type it is guessed from the file extension
  /// ([guessMimeType]), else [mimeHint] is used (the message decoder passes
  /// `image/*` for image messages, ...), else `application/octet-stream`.
  factory Attachment.fromJson(
    Object? json, {
    AttachmentJsonKeys keys = const AttachmentJsonKeys(),
    String? mimeHint,
  }) {
    final map = json is String ? {keys.remoteUrl: json} : readMap(json);
    final remoteUrl =
        readOptionalString(map[keys.remoteUrl]) ??
        readOptionalString(map[_urlAlias]);
    final localPath = readOptionalString(map[keys.localPath]);
    final name = readOptionalString(map[keys.name]);
    return Attachment(
      mimeType:
          readOptionalString(map[keys.mimeType]) ??
          guessMimeType(remoteUrl ?? localPath ?? name) ??
          mimeHint ??
          fallbackMimeType,
      localPath: localPath,
      remoteUrl: remoteUrl,
      thumbnailUrl: readOptionalString(map[keys.thumbnailUrl]),
      size: readInt(map[keys.size]),
      width: readInt(map[keys.width]),
      height: readInt(map[keys.height]),
      duration: readDuration(map[keys.duration]),
      name: name,
    );
  }

  /// The type of a file whose kind is unknown; shown as a file.
  static const fallbackMimeType = 'application/octet-stream';

  static const _urlAlias = 'url';

  /// The mime type for a URL, path or file name by its extension, or null.
  /// Query strings and fragments are ignored.
  static String? guessMimeType(String? path) {
    if (path == null) return null;
    final uri = Uri.tryParse(path);
    final clean = uri != null && uri.hasScheme ? uri.path : path;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot < clean.lastIndexOf('/')) return null;
    return _mimeByExtension[clean.substring(dot + 1).toLowerCase()];
  }

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'mp4': 'video/mp4',
    'm4v': 'video/x-m4v',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    '3gp': 'video/3gpp',
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  final String mimeType;
  final String? localPath;
  final String? remoteUrl;
  final String? thumbnailUrl;

  /// Size in bytes.
  final int? size;
  final int? width;
  final int? height;
  final Duration? duration;

  /// Original file name, shown for file messages.
  final String? name;

  AttachmentKind get kind {
    if (mimeType.startsWith('image/')) return AttachmentKind.image;
    if (mimeType.startsWith('video/')) return AttachmentKind.video;
    if (mimeType.startsWith('audio/')) return AttachmentKind.audio;
    return AttachmentKind.file;
  }

  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  bool get isUploaded => remoteUrl != null;

  /// Remote URL when uploaded, otherwise the local path.
  String? get source => remoteUrl ?? localPath;

  Attachment copyWith({
    String? mimeType,
    String? localPath,
    String? remoteUrl,
    String? thumbnailUrl,
    int? size,
    int? width,
    int? height,
    Duration? duration,
    String? name,
  }) {
    return Attachment(
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      name: name ?? this.name,
    );
  }

  Map<String, Object?> toJson({
    AttachmentJsonKeys keys = const AttachmentJsonKeys(),
  }) {
    return withoutNulls({
      keys.mimeType: mimeType,
      keys.localPath: localPath,
      keys.remoteUrl: remoteUrl,
      keys.thumbnailUrl: thumbnailUrl,
      keys.size: size,
      keys.width: width,
      keys.height: height,
      keys.duration: duration?.inMilliseconds,
      keys.name: name,
    });
  }

  @override
  bool operator ==(Object other) {
    return other is Attachment &&
        other.mimeType == mimeType &&
        other.localPath == localPath &&
        other.remoteUrl == remoteUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.size == size &&
        other.width == width &&
        other.height == height &&
        other.duration == duration &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(
    mimeType,
    localPath,
    remoteUrl,
    thumbnailUrl,
    size,
    width,
    height,
    duration,
    name,
  );

  @override
  String toString() => 'Attachment($mimeType, ${source ?? '-'})';
}
