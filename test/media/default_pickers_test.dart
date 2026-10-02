import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46]);

class _Picker extends ImagePicker {
  final List<(double?, double?, int?)> limits = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    limits.add((maxWidth, maxHeight, imageQuality));
    return XFile.fromData(_jpeg, path: 'IMG_0001.heic', mimeType: 'image/heic');
  }

  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    limits.add((maxWidth, maxHeight, imageQuality));
    return [
      XFile.fromData(
        Uint8List.fromList('GIF89a......'.codeUnits),
        path: 'party.gif',
      ),
    ];
  }
}

void main() {
  group('imageTypeOf', () {
    test('reads the type from the first bytes', () {
      expect(imageTypeOf(_jpeg)?.mimeType, 'image/jpeg');
      expect(
        imageTypeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])?.mimeType,
        'image/png',
      );
      expect(imageTypeOf('GIF89a'.codeUnits)?.mimeType, 'image/gif');
      expect(
        imageTypeOf('RIFF\x00\x00\x00\x00WEBP'.codeUnits)?.extension,
        '.webp',
      );
      expect(
        imageTypeOf('\x00\x00\x00\x18ftypheic'.codeUnits)?.mimeType,
        'image/heic',
      );
      expect(imageTypeOf(const [1, 2, 3]), isNull);
    });
  });

  testWidgets('photos are picked with the size and quality limits', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final picker = _Picker();
    final pick = DefaultAttachmentPicker(
      imagePicker: picker,
      maxDimension: 1920,
      imageQuality: 80,
    );

    final shot = await tester.runAsync(
      () => pick(context, AttachmentSource.camera),
    );
    final gallery = await tester.runAsync(
      () => pick(context, AttachmentSource.gallery),
    );

    expect(picker.limits, [(1920.0, 1920.0, 80), (1920.0, 1920.0, 80)]);
    // The camera returned JPEG data under a .heic name.
    expect(shot!.single.mimeType, 'image/jpeg');
    expect(shot.single.name, 'IMG_0001.jpg');
    expect(gallery!.single.mimeType, 'image/gif');
    expect(gallery.single.name, 'party.gif');
  });

  testWidgets('null limits pick the originals', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final picker = _Picker();
    await tester.runAsync(
      () => DefaultAttachmentPicker(
        imagePicker: picker,
      ).call(context, AttachmentSource.gallery),
    );

    expect(picker.limits, [(null, null, null)]);
  });
}
