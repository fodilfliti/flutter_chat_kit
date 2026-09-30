import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/audio_player_hub.dart';
import 'package:flutter_chat_kit/src/media/chat_media_store.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_media_scope.dart';

/// A voice message: play / pause, waveform bars colored up to the position
/// (drag or tap to seek), the time, and a 1x / 1.5x / 2x speed button while
/// it is the current one. Plays through the shared [AudioPlayerHub], from
/// the local or stored file when there is one.
class AudioMessageView extends StatefulWidget {
  const AudioMessageView({
    required this.message,
    required this.color,
    required this.metaStyle,
    this.activeColor,
    this.hub,
    this.store,
    this.speeds = const [1, 1.5, 2],
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final AudioMessage message;

  /// Icon and unplayed bar color.
  final Color color;
  final TextStyle metaStyle;

  /// Played bars; defaults to [color].
  final Color? activeColor;

  /// Default to the `ChatMediaScope` ones.
  final AudioPlayerHub? hub;
  final ChatMediaStore? store;
  final List<double> speeds;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  State<AudioMessageView> createState() => _AudioMessageViewState();
}

class _AudioMessageViewState extends State<AudioMessageView> {
  bool _loading = false;

  String get _id => widget.message.localId;

  AudioPlayerHub? get _hub => widget.hub ?? ChatMediaScope.of(context).audio;

  ChatMediaStore? get _store =>
      widget.store ?? ChatMediaScope.of(context).store;

  Future<void> _toggle(AudioPlayerHub hub) async {
    if (hub.isPlayingId(_id)) return await hub.pause();
    final audio = widget.message.audio;
    final local = audio.localPath;
    if (!kIsWeb && local != null && File(local).existsSync()) {
      return await hub.play(_id, localPath: local);
    }
    final url = audio.remoteUrl;
    if (url == null) return;
    final store = _store;
    if (store == null || !store.isSupported) {
      return await hub.play(_id, url: url);
    }
    setState(() => _loading = true);
    try {
      final file = await store.fetch(url);
      if (!mounted) return;
      await hub.play(_id, localPath: file.path);
    } on Object {
      if (mounted) await hub.play(_id, url: url);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _seek(AudioPlayerHub hub, double fraction, Duration total) {
    unawaited(hub.seek(total * fraction.clamp(0.0, 1.0), id: _id));
  }

  void _cycleSpeed(AudioPlayerHub hub) {
    final speeds = widget.speeds;
    final i = speeds.indexOf(hub.speed);
    unawaited(hub.setSpeed(speeds[(i + 1) % speeds.length]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final hub = _hub;
    final m = widget.message;
    final color = widget.color;
    final active = widget.activeColor ?? color;
    if (hub == null) {
      return _layout(
        theme,
        button: Icon(
          Icons.play_arrow_rounded,
          color: color.withValues(alpha: 0.4),
          size: theme.size(24),
        ),
        wave: _Waveform(
          bars: m.waveform,
          progress: 0,
          color: color.withValues(alpha: 0.35),
          activeColor: active,
        ),
        time: Text(
          widget.formatters.formatDuration(m.duration),
          style: widget.metaStyle,
        ),
      );
    }
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final playing = hub.isPlayingId(_id);
        final current = hub.currentId == _id;
        final button = _loading
            ? SizedBox.square(
                dimension: theme.size(24),
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : IconButton(
                onPressed: () => unawaited(_toggle(hub)),
                tooltip: playing ? widget.strings.pause : widget.strings.play,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: color,
                  size: theme.size(32),
                ),
              );
        final position = hub.position(_id);
        final known = hub.duration(_id);
        return _layout(
          theme,
          button: button,
          wave: ValueListenableBuilder<Duration?>(
            valueListenable: known,
            builder: (context, loaded, _) {
              final total = loaded ?? m.duration;
              return ValueListenableBuilder<Duration>(
                valueListenable: position,
                builder: (context, at, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    double fractionAt(double dx) => constraints.maxWidth <= 0
                        ? 0
                        : dx / constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _seek(hub, fractionAt(d.localPosition.dx), total),
                      onHorizontalDragUpdate: (d) =>
                          _seek(hub, fractionAt(d.localPosition.dx), total),
                      child: _Waveform(
                        bars: m.waveform,
                        progress: total.inMilliseconds <= 0
                            ? 0
                            : at.inMilliseconds / total.inMilliseconds,
                        color: color.withValues(alpha: 0.35),
                        activeColor: active,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          time: ValueListenableBuilder<Duration>(
            valueListenable: position,
            builder: (context, at, _) => Text(
              widget.formatters.formatDuration(
                current && at > Duration.zero ? at : m.duration,
              ),
              style: widget.metaStyle,
            ),
          ),
          speed: current
              ? TextButton(
                  onPressed: () => _cycleSpeed(hub),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: theme.size(6)),
                  ),
                  child: Text(
                    widget.strings.playbackSpeed(hub.speed),
                    style: widget.metaStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _layout(
    ChatTheme theme, {
    required Widget button,
    required Widget wave,
    required Widget time,
    Widget? speed,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: theme.size(260),
        minWidth: theme.size(200),
      ),
      child: Row(
        children: [
          button,
          SizedBox(width: theme.size(4)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: theme.size(28), child: wave),
                Row(children: [time, const Spacer(), ?speed]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Waveform bars; the first [progress] fraction uses [activeColor].
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.progress,
    required this.color,
    required this.activeColor,
  });

  final List<double> bars;
  final double progress;
  final Color color;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: WaveformPainter(
        bars: bars,
        progress: progress,
        color: color,
        activeColor: activeColor,
      ),
    );
  }
}

/// Paints rounded waveform bars. An empty [bars] draws a flat line of
/// short bars.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.bars,
    required this.progress,
    required this.color,
    required this.activeColor,
    this.barCount = 40,
  });

  final List<double> bars;
  final double progress;
  final Color color;
  final Color activeColor;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final values = bars.isEmpty ? List.filled(barCount, 0.15) : bars;
    final n = values.length;
    if (n == 0 || size.width <= 0) return;
    final slot = size.width / n;
    final width = (slot * 0.6).clamp(1.0, 4.0);
    final played = progress.clamp(0.0, 1.0) * n;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final h = (values[i].clamp(0.0, 1.0) * size.height).clamp(
        width,
        size.height,
      );
      final x = slot * i + slot / 2;
      paint
        ..color = i < played ? activeColor : color
        ..strokeWidth = width;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2 + width / 2),
        Offset(x, (size.height + h) / 2 - width / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.activeColor != activeColor ||
      !identical(old.bars, bars);
}
