import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// What an [Attachment] is, from its mime type.
enum AttachmentKind {
  /// `image/*`.
  image,

  /// `video/*`.
  video,

  /// `audio/*`.
  audio,

  /// Anything else, including `application/octet-stream`.
  file,
}

/// A media or file payload of a message.
///
/// While uploading, [localPath] is set and [remoteUrl] is null; the
/// `ChatUploader` fills [remoteUrl]. [width] and [height] let the UI
/// reserve space before the image loads.
///
/// In JSON it can be an object or a bare URL string; only the URL is
/// needed:
///
/// ```json
/// {"remote_url": "https://cdn.example.com/a.jpg", "mime_type": "image/jpeg",
///  "width": 1080, "height": 1440, "size": 245100}
/// ```
///
/// Field names come from [AttachmentJsonKeys].
@immutable
class Attachment {
  /// An attachment; only [mimeType] is required. Set [localPath] for a file
  /// on this device, or [remoteUrl] for one already uploaded.
  const Attachment({
    required this.mimeType,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.size,
    this.width,
    this.height,
    this.duration,
    this.name,
  });

  /// Reads an attachment object, or a bare URL string.
  ///
  /// The URL is read from `remote_url`, else `url`. Without a mime type it
  /// is guessed from the extension of the URL, path or name
  /// ([guessMimeType]), else [mimeHint] is used (the message decoder passes
  /// `image/*` for image messages, ...), else [fallbackMimeType]. Numbers
  /// may be numbers or numeric strings; `duration_ms` is milliseconds.
  ///
  /// It never throws: anything that is not a string or an object reads as
  /// an attachment without a URL. `ChatJsonCheck` reports that case.
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
      thumbnailPath: readOptionalString(map[keys.thumbnailPath]),
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
  ///
  /// Query strings and fragments are ignored and case does not matter.
  /// Known extensions: images (jpg, jpeg, png, gif, webp, heic, heif, bmp,
  /// svg), videos (mp4, m4v, mov, webm, mkv, 3gp), audio (m4a, mp3, aac,
  /// ogg, oga, opus, wav, flac) and documents (pdf, zip, doc, docx, xls,
  /// xlsx, ppt, pptx, txt, csv).
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

  /// The file type, such as `image/jpeg` (JSON `mime_type`). Decides
  /// [kind], so how the file is shown. Guessed when missing.
  final String mimeType;

  /// Path of the file on this device (JSON `local_path`), set while it is
  /// waiting to upload. Other devices never have it.
  final String? localPath;

  /// Where the file can be downloaded (JSON `remote_url`, or `url`). Null
  /// until the upload finishes.
  final String? remoteUrl;

  /// A small preview image, such as a video poster (JSON `thumbnail_url`).
  /// Without it a video bubble shows a placeholder instead of a poster.
  final String? thumbnailUrl;

  /// A poster made on this device for a video being sent (JSON
  /// `thumbnail_path`), shown until [thumbnailUrl] is known. The outbox
  /// uploads it when the uploader returns no thumbnail. Other devices never
  /// have it.
  final String? thumbnailPath;

  /// Size in bytes (JSON `size`), shown on file messages.
  final int? size;

  /// Width in pixels (JSON `width`). With [height] it reserves the bubble
  /// size, so the list does not jump when the media loads.
  final int? width;

  /// Height in pixels (JSON `height`). See [width].
  final int? height;

  /// Length of a video or audio file (JSON `duration_ms`, milliseconds).
  final Duration? duration;

  /// Original file name (JSON `name`), shown for file messages and used to
  /// guess the mime type.
  final String? name;

  /// Image, video, audio or file, from [mimeType].
  AttachmentKind get kind {
    if (mimeType.startsWith('image/')) return AttachmentKind.image;
    if (mimeType.startsWith('video/')) return AttachmentKind.video;
    if (mimeType.startsWith('audio/')) return AttachmentKind.audio;
    return AttachmentKind.file;
  }

  /// [width] divided by [height], or null when either is missing or zero.
  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  /// Whether [remoteUrl] is set.
  bool get isUploaded => remoteUrl != null;

  /// Remote URL when uploaded, otherwise the local path.
  String? get source => remoteUrl ?? localPath;

  /// A copy with the given fields replaced; null keeps the current value.
  Attachment copyWith({
    String? mimeType,
    String? localPath,
    String? remoteUrl,
    String? thumbnailUrl,
    String? thumbnailPath,
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
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      name: name ?? this.name,
    );
  }

  /// This attachment as JSON with the names of [keys]; null fields are left
  /// out.
  Map<String, Object?> toJson({
    AttachmentJsonKeys keys = const AttachmentJsonKeys(),
  }) {
    return withoutNulls({
      keys.mimeType: mimeType,
      keys.localPath: localPath,
      keys.remoteUrl: remoteUrl,
      keys.thumbnailUrl: thumbnailUrl,
      keys.thumbnailPath: thumbnailPath,
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
        other.thumbnailPath == thumbnailPath &&
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
    thumbnailPath,
    size,
    width,
    height,
    duration,
    name,
  );

  @override
  String toString() => 'Attachment($mimeType, ${source ?? '-'})';
}
