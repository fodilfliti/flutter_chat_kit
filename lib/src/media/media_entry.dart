import 'package:flutter/foundation.dart';

/// Index record of a file kept by `ChatMediaStore`.
@immutable
class MediaEntry {
  const MediaEntry({
    required this.remoteUrl,
    required this.fileName,
    required this.size,
    required this.lastAccess,
    this.mimeType,
  });

  final String remoteUrl;

  /// Name inside the user's media folder (the folder itself can move, for
  /// example when iOS relocates the app container).
  final String fileName;

  /// Bytes on disk.
  final int size;
  final String? mimeType;

  /// Last read or write, for least-recently-used eviction.
  final DateTime lastAccess;

  MediaEntry copyWith({DateTime? lastAccess}) => MediaEntry(
    remoteUrl: remoteUrl,
    fileName: fileName,
    size: size,
    mimeType: mimeType,
    lastAccess: lastAccess ?? this.lastAccess,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaEntry &&
      other.remoteUrl == remoteUrl &&
      other.fileName == fileName &&
      other.size == size &&
      other.mimeType == mimeType &&
      other.lastAccess == lastAccess;

  @override
  int get hashCode =>
      Object.hash(remoteUrl, fileName, size, mimeType, lastAccess);
}
