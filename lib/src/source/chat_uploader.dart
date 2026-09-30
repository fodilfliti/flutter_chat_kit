import 'package:flutter_chat_kit/src/models/attachment.dart';

/// Progress of one attachment upload.
sealed class UploadProgress {
  const UploadProgress();
}

final class UploadRunning extends UploadProgress {
  const UploadRunning(this.fraction);

  /// 0..1.
  final double fraction;
}

final class UploadDone extends UploadProgress {
  const UploadDone({required this.remoteUrl, this.thumbnailUrl});

  final String remoteUrl;
  final String? thumbnailUrl;
}

/// Uploads attachment files to the app's storage (Firebase Storage,
/// Supabase Storage, S3, ...).
///
/// The stream emits any number of [UploadRunning] values and ends with one
/// [UploadDone]. Errors are `AppFailure`s.
abstract interface class ChatUploader {
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  });
}
