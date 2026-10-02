import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/fake/fake_chat_source.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// Pretends to upload: ten progress steps, then "returns" the local file as
/// the remote URL. The kit adopts the local file into its media store, so
/// the sender never downloads its own upload.
///
/// A real app uploads to Firebase Storage, Supabase Storage or S3 here.
class FakeUploader implements ChatUploader {
  FakeUploader(this.source);

  final FakeChatSource source;

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    for (var step = 1; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!source.online) throw const NetworkFailure();
      yield UploadRunning(step / 10);
    }
    final path = attachment.localPath;
    if (path == null) throw const StorageFailure();
    yield UploadDone(remoteUrl: kIsWeb ? path : Uri.file(path).toString());
  }
}
