import 'package:flutter_chat_kit/src/models/attachment.dart';

/// Progress of one attachment upload, emitted by [ChatUploader.upload]:
/// either [UploadRunning] or [UploadDone].
sealed class UploadProgress {
  /// Base constructor for the two progress types.
  const UploadProgress();
}

/// The upload is in progress; the bubble shows the progress as a ring
/// (averaged over the message's attachments).
final class UploadRunning extends UploadProgress {
  /// Reports that [fraction] of the file has been sent.
  const UploadRunning(this.fraction);

  /// Share of the file sent so far, from 0 to 1. Values outside that range
  /// are clamped.
  final double fraction;
}

/// The upload finished; the kit stores the URLs on the attachment and then
/// calls `ChatSource.send`.
final class UploadDone extends UploadProgress {
  /// Reports the stored file at [remoteUrl], with an optional
  /// [thumbnailUrl].
  const UploadDone({required this.remoteUrl, this.thumbnailUrl});

  /// Public URL of the stored file, saved as `Attachment.remoteUrl` and
  /// sent to the backend (JSON `remote_url`).
  final String remoteUrl;

  /// URL of a small preview (an image thumbnail or a video poster), saved
  /// as `Attachment.thumbnailUrl`. Null when the storage makes none.
  final String? thumbnailUrl;
}

/// Uploads attachment files to the app's storage (Firebase Storage,
/// Supabase Storage, S3, ...).
///
/// The stream emits any number of [UploadRunning] values and ends with one
/// [UploadDone]. Errors are `AppFailure`s.
///
/// Pass it as `ChatKit.uploader`. Without one, the composer hides the voice
/// and attachment buttons. See the storage sections of
/// doc/adapters/firestore.md and doc/adapters/supabase.md.
abstract interface class ChatUploader {
  /// Uploads the file at `attachment.localPath` and reports progress.
  ///
  /// The outbox calls it before `ChatSource.send`, once for each attachment
  /// that has no `remoteUrl` yet. [roomId] and [localId] identify the
  /// message, which is useful for a stable storage path, so a retried
  /// upload overwrites the same file. The kit cancels the subscription when
  /// the user cancels the send.
  ///
  /// Rules:
  /// - End with one [UploadDone]. A stream that closes without it fails
  ///   with `StorageFailure`.
  /// - Throw `NetworkFailure` or `TimeoutFailure` to retry later; any other
  ///   error marks the message failed.
  /// - Read the file with `attachment.openRead()` or
  ///   `attachment.readAsBytes()` (see `AttachmentFile`), not
  ///   `File(localPath)`: on the web `localPath` is a `blob:` URL.
  /// - A video may also bring a `thumbnailPath` (a poster made on the
  ///   device). When [UploadDone.thumbnailUrl] is null the kit uploads it
  ///   through this same method, as an image with local id
  ///   `'<localId>_thumb'`.
  ///
  /// ```dart
  /// @override
  /// Stream<UploadProgress> upload(Attachment attachment,
  ///     {required String roomId, required String localId}) async* {
  ///   final path = 'chat/$roomId/$localId/${attachment.name ?? 'file'}';
  ///   yield const UploadRunning(0);
  ///   final url = await storage.putBytes(
  ///     path,
  ///     await attachment.readAsBytes(),
  ///   );
  ///   yield UploadDone(remoteUrl: url);
  /// }
  /// ```
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  });
}
