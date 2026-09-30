import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_image.dart';

/// A video poster (`thumbnailUrl`, else a placeholder) with a play button
/// and the duration. Playback happens in the media viewer.
class VideoMessageView extends StatelessWidget {
  const VideoMessageView({
    required this.video,
    this.progress,
    this.onTap,
    this.heroTag,
    this.maxWidth = 300,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final Attachment video;

  /// Upload fraction 0..1, or null when not uploading.
  final ValueListenable<double?>? progress;
  final VoidCallback? onTap;
  final Object? heroTag;
  final double maxWidth;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  Widget build(BuildContext context) {
    final duration = video.duration;
    Widget poster = ChatImage(
      attachment: video,
      thumbnail: true,
      strings: strings,
    );
    final tag = heroTag;
    if (tag != null) poster = Hero(tag: tag, child: poster);
    final progress = this.progress;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AspectRatio(
        aspectRatio: (video.aspectRatio ?? 16 / 9).clamp(0.6, 1.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            poster,
            Center(
              child: progress == null
                  ? _play()
                  : ValueListenableBuilder<double?>(
                      valueListenable: progress,
                      builder: (context, value, _) => value == null
                          ? _play()
                          : SizedBox.square(
                              dimension: 44,
                              child: CircularProgressIndicator(
                                value: value <= 0 ? null : value,
                                strokeWidth: 3,
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                    ),
            ),
            if (duration != null)
              PositionedDirectional(
                start: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      formatters.formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    );
  }

  Widget _play() {
    return Semantics(
      button: true,
      label: strings.play,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}
