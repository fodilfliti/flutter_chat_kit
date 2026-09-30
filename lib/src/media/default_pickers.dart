import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

/// Where the composer's attachment sheet picks from.
enum AttachmentSource { camera, gallery, video, file }

/// Picks files for the composer; replaces [DefaultAttachmentPicker].
/// Returns an empty list when the user cancels.
typedef AttachmentPicker =
    Future<List<Attachment>> Function(
      BuildContext context,
      AttachmentSource source,
    );

/// `image_picker` (camera, gallery, video) and `file_picker` (files),
/// returning attachments with their size, MIME type, and image or video
/// dimensions (and video duration) so bubbles reserve space before upload.
/// Permissions are requested by those plugins.
class DefaultAttachmentPicker {
  const DefaultAttachmentPicker({this._imagePicker});

  final ImagePicker? _imagePicker;

  Future<List<Attachment>> call(
    BuildContext context,
    AttachmentSource source,
  ) async {
    final picker = _imagePicker ?? ImagePicker();
    final List<XFile> files;
    switch (source) {
      case AttachmentSource.camera:
        final shot = await picker.pickImage(source: ImageSource.camera);
        files = [?shot];
      case AttachmentSource.gallery:
        files = await picker.pickMultipleMedia();
      case AttachmentSource.video:
        final video = await picker.pickVideo(source: ImageSource.gallery);
        files = [?video];
      case AttachmentSource.file:
        final picked = await FilePicker.pickFiles();
        files = [for (final f in picked) f.xFile];
    }
    return [for (final f in files) await attachmentFromXFile(f)];
  }
}

/// An [Attachment] for a local [file], reading its size, MIME type and,
/// for images and videos, dimensions (and video duration). Values that
/// cannot be read stay null.
Future<Attachment> attachmentFromXFile(XFile file) async {
  final name = file.name.isNotEmpty ? file.name : p.basename(file.path);
  final mimeType =
      file.mimeType ?? mimeTypeForPath(name) ?? 'application/octet-stream';
  int? size;
  try {
    size = await file.length();
  } on Object {
    size = null;
  }
  var attachment = Attachment(
    mimeType: mimeType,
    localPath: file.path,
    size: size,
    name: name,
  );
  if (mimeType.startsWith('image/')) {
    final dimensions = await _imageSize(file);
    if (dimensions != null) {
      attachment = attachment.copyWith(
        width: dimensions.width,
        height: dimensions.height,
      );
    }
  } else if (mimeType.startsWith('video/') && !kIsWeb) {
    attachment = await _withVideoInfo(attachment, file.path);
  }
  return attachment;
}

/// The MIME type for the extension of [path], or null when unknown.
String? mimeTypeForPath(String path) =>
    _mimeTypes[p.extension(path).toLowerCase()];

Future<({int width, int height})?> _imageSize(XFile file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = kIsWeb
        ? await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes())
        : await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (width: descriptor.width, height: descriptor.height);
  } on Object {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

Future<Attachment> _withVideoInfo(Attachment attachment, String path) async {
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize().timeout(const Duration(seconds: 5));
    final value = controller.value;
    return attachment.copyWith(
      width: value.size.width.round(),
      height: value.size.height.round(),
      duration: value.duration,
    );
  } on Object {
    return attachment;
  } finally {
    unawaited(controller.dispose());
  }
}

const _mimeTypes = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.bmp': 'image/bmp',
  '.mp4': 'video/mp4',
  '.m4v': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.3gp': 'video/3gpp',
  '.mkv': 'video/x-matroska',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/opus',
  '.wav': 'audio/wav',
  '.pdf': 'application/pdf',
  '.txt': 'text/plain',
  '.csv': 'text/csv',
  '.zip': 'application/zip',
  '.doc': 'application/msword',
  '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.ppt': 'application/vnd.ms-powerpoint',
  '.pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};
