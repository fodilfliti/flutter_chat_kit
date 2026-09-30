import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_image.dart';

/// Builds one grid cell; defaults to [ChatImage].
typedef MediaCellBuilder =
    Widget Function(BuildContext context, Attachment attachment, int index);

/// The images of a message: one at its own aspect ratio, or a 2, 3 or 2×2
/// grid with "+N" on the last cell. The size is fixed before any image
/// loads, and the upload overlay rebuilds on its own.
class ImageMessageView extends StatelessWidget {
  const ImageMessageView({
    required this.images,
    this.progress,
    this.onTap,
    this.cellBuilder,
    this.heroTags,
    this.spacing = 2,
    this.maxWidth = 300,
    this.strings = const ChatStrings(),
    super.key,
  });

  final List<Attachment> images;

  /// Upload fraction 0..1, or null when not uploading.
  final ValueListenable<double?>? progress;

  /// Called with the index of the tapped image.
  final ValueChanged<int>? onTap;
  final MediaCellBuilder? cellBuilder;

  /// Hero tags per image, matching the media viewer's.
  final List<Object>? heroTags;
  final double spacing;
  final double maxWidth;
  final ChatStrings strings;

  /// Aspect ratio of the whole grid.
  static double aspectRatioOf(List<Attachment> images) {
    if (images.length == 1) {
      return (images.first.aspectRatio ?? 1).clamp(0.6, 1.8);
    }
    return images.length == 2 ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final grid = AspectRatio(
      aspectRatio: aspectRatioOf(images),
      child: _grid(context),
    );
    final progress = this.progress;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: progress == null
          ? grid
          : Stack(
              children: [
                grid,
                Positioned.fill(
                  child: ValueListenableBuilder<double?>(
                    valueListenable: progress,
                    builder: (context, value, _) => value == null
                        ? const SizedBox.shrink()
                        : _UploadOverlay(value: value),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _grid(BuildContext context) {
    final gap = SizedBox.square(dimension: spacing);
    Widget cell(int i) => Expanded(child: _cell(context, i));
    switch (images.length) {
      case 1:
        return _cell(context, 0);
      case 2:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cell(0), gap, cell(1)],
        );
      case 3:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(0),
            gap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cell(1), gap, cell(2)],
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cell(0), gap, cell(1)],
              ),
            ),
            gap,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cell(2), gap, cell(3)],
              ),
            ),
          ],
        );
    }
  }

  Widget _cell(BuildContext context, int index) {
    final image = images[index];
    var child =
        cellBuilder?.call(context, image, index) ??
        ChatImage(attachment: image, strings: strings);
    final tags = heroTags;
    if (tags != null && index < tags.length) {
      child = Hero(tag: tags[index], child: child);
    }
    final more = images.length - 4;
    final onTap = this.onTap;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (index == 3 && more > 0)
          ColoredBox(
            color: Colors.black45,
            child: Center(
              child: Text(
                strings.moreMedia(more),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (onTap != null)
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: () => onTap(index)),
          ),
      ],
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: SizedBox.square(
          dimension: 44,
          child: CircularProgressIndicator(
            value: value <= 0 ? null : value,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
    );
  }
}
