import 'package:flutter/foundation.dart';
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

  factory Attachment.fromJson(Map<String, Object?> json) {
    return Attachment(
      mimeType: readOptionalString(json['mime_type']) ?? _fallbackMime,
      localPath: readOptionalString(json['local_path']),
      remoteUrl: readOptionalString(json['remote_url']),
      thumbnailUrl: readOptionalString(json['thumbnail_url']),
      size: readInt(json['size']),
      width: readInt(json['width']),
      height: readInt(json['height']),
      duration: readDuration(json['duration_ms']),
      name: readOptionalString(json['name']),
    );
  }

  static const _fallbackMime = 'application/octet-stream';

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

  Map<String, Object?> toJson() {
    return withoutNulls({
      'mime_type': mimeType,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'thumbnail_url': thumbnailUrl,
      'size': size,
      'width': width,
      'height': height,
      'duration_ms': duration?.inMilliseconds,
      'name': name,
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
