import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';

/// Reads an attachment's local file the same way on every platform,
/// including the web, where `localPath` is a `blob:` URL that `dart:io`
/// can't open. Use it in a `ChatUploader` instead of `File(localPath)`.
///
/// ```dart
/// // Small files: one request body.
/// final bytes = await attachment.readAsBytes();
///
/// // Large files (videos): stream them instead of loading them in memory.
/// final request = http.StreamedRequest('PUT', uploadUri)
///   ..contentLength = attachment.size;
/// attachment.openRead().listen(
///   request.sink.add,
///   onDone: request.sink.close,
///   onError: request.sink.addError,
/// );
/// final response = await client.send(request);
/// ```
extension AttachmentFile on Attachment {
  /// The local file, or null when the attachment has no `localPath` (it
  /// is already uploaded).
  XFile? get file {
    final path = localPath;
    if (path == null) return null;
    return XFile(path, mimeType: mimeType, name: name, length: size);
  }

  /// The local file's bytes, in chunks; optionally only from [start]
  /// (inclusive) to [end] (exclusive), for resumable uploads. Throws a
  /// [StateError] without a `localPath`.
  Stream<Uint8List> openRead([int? start, int? end]) =>
      _local.openRead(start, end);

  /// The whole local file in memory. Prefer [openRead] for large files.
  /// Throws a [StateError] without a `localPath`.
  Future<Uint8List> readAsBytes() => _local.readAsBytes();

  XFile get _local =>
      file ?? (throw StateError('The attachment has no localPath'));
}
