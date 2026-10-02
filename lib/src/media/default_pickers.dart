import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:stream_thumbnail/stream_thumbnail.dart';
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
///
/// Photos from the camera and gallery are scaled to [maxDimension] and
/// re-encoded at [imageQuality] (`ChatConfig.imageMaxDimension` and
/// `imageQuality` when the composer creates it), which also turns iPhone
/// HEIC into JPEG. Files picked as documents are sent untouched, so a GIF
/// that must stay animated on every Android version goes through "File".
/// A custom [AttachmentPicker] should shrink photos the same way.
class DefaultAttachmentPicker {
  const DefaultAttachmentPicker({
    this._imagePicker,
    this.maxDimension,
    this.imageQuality,
  });

  final ImagePicker? _imagePicker;

  /// Longest side of picked photos, in pixels. Null keeps the original.
  final int? maxDimension;

  /// JPEG quality (0-100) of picked photos. Null keeps the encoding.
  final int? imageQuality;

  Future<List<Attachment>> call(
    BuildContext context,
    AttachmentSource source,
  ) async {
    final picker = _imagePicker ?? ImagePicker();
    final max = maxDimension?.toDouble();
    final List<XFile> files;
    switch (source) {
      case AttachmentSource.camera:
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: max,
          maxHeight: max,
          imageQuality: imageQuality,
        );
        files = [?shot];
      case AttachmentSource.gallery:
        files = await picker.pickMultipleMedia(
          maxWidth: max,
          maxHeight: max,
          imageQuality: imageQuality,
        );
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
///
/// For images the type comes from the file's first bytes when they say
/// otherwise: a resized pick can be JPEG data under a `.heic` or `.gif`
/// name, and the name's extension is corrected with it.
///
/// For videos on Android, iOS and the web, [videoPoster] makes a JPEG of
/// the first frame (480 px on the long side) as `Attachment.thumbnailPath`,
/// so the bubble shows a poster at once and the outbox can upload it when
/// the uploader makes none. Desktop keeps the placeholder.
Future<Attachment> attachmentFromXFile(
  XFile file, {
  bool videoPoster = true,
}) async {
  var name = file.name.isNotEmpty ? file.name : p.basename(file.path);
  var mimeType =
      file.mimeType ?? mimeTypeForPath(name) ?? 'application/octet-stream';
  if (mimeType.startsWith('image/')) {
    final sniffed = await _sniffImageType(file);
    if (sniffed != null && sniffed.mimeType != mimeType) {
      mimeType = sniffed.mimeType;
      name = p.setExtension(name, sniffed.extension);
    }
  }
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
  } else if (mimeType.startsWith('video/')) {
    if (!kIsWeb) attachment = await _withVideoInfo(attachment, file.path);
    if (videoPoster) attachment = await _withPoster(attachment, file.path);
  }
  return attachment;
}

bool get _postersSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

Future<Attachment> _withPoster(Attachment attachment, String path) async {
  if (!_postersSupported) return attachment;
  final w = attachment.width;
  final h = attachment.height;
  final portrait = w != null && h != null && h > w;
  try {
    // Bounding one side keeps the aspect ratio on every platform.
    final poster = await StreamThumbnail.thumbnailFile(
      video: path,
      imageFormat: StreamThumbnailFormat.jpeg,
      maxWidth: portrait ? 0 : 480,
      maxHeight: portrait ? 480 : 0,
      quality: 75,
    ).timeout(const Duration(seconds: 10));
    return attachment.copyWith(thumbnailPath: poster.path);
  } on Object {
    return attachment;
  }
}

/// The MIME type for the extension of [path], or null when unknown.
String? mimeTypeForPath(String path) =>
    _mimeTypes[p.extension(path).toLowerCase()];

Future<({String mimeType, String extension})?> _sniffImageType(
  XFile file,
) async {
  final List<int> head;
  try {
    final length = await file.length();
    head = await file
        .openRead(0, length < 12 ? length : 12)
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
  } on Object {
    return null;
  }
  return imageTypeOf(head);
}

/// The image type that the first bytes of a file ([head], 12 are enough)
/// announce, or null when they match none of JPEG, PNG, GIF, WebP and
/// HEIC.
@visibleForTesting
({String mimeType, String extension})? imageTypeOf(List<int> head) {
  bool at(int offset, List<int> bytes) {
    if (head.length < offset + bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (head[offset + i] != bytes[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) {
    return (mimeType: 'image/jpeg', extension: '.jpg');
  }
  if (at(0, const [0x89, 0x50, 0x4E, 0x47])) {
    return (mimeType: 'image/png', extension: '.png');
  }
  if (at(0, 'GIF8'.codeUnits)) {
    return (mimeType: 'image/gif', extension: '.gif');
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    return (mimeType: 'image/webp', extension: '.webp');
  }
  if (at(4, 'ftyphei'.codeUnits) || at(4, 'ftypmif1'.codeUnits)) {
    return (mimeType: 'image/heic', extension: '.heic');
  }
  return null;
}

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
