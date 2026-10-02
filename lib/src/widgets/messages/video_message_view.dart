import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_formatters.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';
import 'package:flutter_chat_pro/src/widgets/media/chat_image.dart';

/// A video poster (the local `thumbnailPath` while sending, else
/// `thumbnailUrl`, else a placeholder) with a play button and the
/// duration. Playback happens in the media viewer.
class VideoMessageView extends StatelessWidget {
  const VideoMessageView({
    required this.video,
    this.progress,
    this.onTap,
    this.heroTag,
    this.maxWidth,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final Attachment video;

  /// Upload fraction 0..1, `Outbox.compressing` while the video is being
  /// compressed, or null when not uploading.
  final ValueListenable<double?>? progress;
  final VoidCallback? onTap;
  final Object? heroTag;

  /// Defaults to `ChatMediaStyle.maxWidth`.
  final double? maxWidth;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final media = theme.media;
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
      constraints: BoxConstraints(maxWidth: maxWidth ?? media.maxWidth),
      child: AspectRatio(
        aspectRatio: (video.aspectRatio ?? 16 / 9).clamp(0.6, 1.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            poster,
            Center(
              child: progress == null
                  ? _play(theme)
                  : ValueListenableBuilder<double?>(
                      valueListenable: progress,
                      builder: (context, value, _) {
                        if (value == null) return _play(theme);
                        final spinner = SizedBox.square(
                          dimension: theme.size(44),
                          child: CircularProgressIndicator(
                            value: value <= 0 ? null : value,
                            strokeWidth: 3,
                            color: media.overlayForegroundColor,
                            backgroundColor: media.overlayForegroundColor
                                .withValues(alpha: 0.24),
                          ),
                        );
                        // A negative value is Outbox.compressing.
                        if (value >= 0) return spinner;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            spinner,
                            SizedBox(height: theme.size(8)),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: media.overlayColor,
                                borderRadius: BorderRadius.circular(
                                  media.overlayRadius,
                                ),
                              ),
                              child: Padding(
                                padding: media.overlayPadding,
                                child: Text(
                                  strings.compressing,
                                  style: TextStyle(
                                    color: media.overlayForegroundColor,
                                    fontSize: theme.fontSize(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (duration != null)
              PositionedDirectional(
                start: theme.size(6),
                bottom: theme.size(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: media.overlayColor,
                    borderRadius: BorderRadius.circular(media.overlayRadius),
                  ),
                  child: Padding(
                    padding: media.overlayPadding,
                    child: Text(
                      formatters.formatDuration(duration),
                      style: TextStyle(
                        color: media.overlayForegroundColor,
                        fontSize: theme.fontSize(12),
                      ),
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

  Widget _play(ChatTheme theme) {
    final media = theme.media;
    return Semantics(
      button: true,
      label: strings.play,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: media.overlayColor,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.size(8)),
          child: Icon(
            Icons.play_arrow_rounded,
            color: media.overlayForegroundColor,
            size: theme.size(36),
          ),
        ),
      ),
    );
  }
}
