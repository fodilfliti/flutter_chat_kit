import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/platform/io.dart';
import 'package:web/web.dart' as web;

/// What a [VideoPlayerController] knows about its video.
@immutable
class VideoPlayerValue {
  /// A value; the defaults describe a video that has not loaded.
  const VideoPlayerValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.size = Size.zero,
  });

  /// Whether the metadata (duration and size) loaded.
  final bool isInitialized;

  /// Whether the video is playing.
  final bool isPlaying;

  /// The current playback position.
  final Duration position;

  /// The length of the video.
  final Duration duration;

  /// How far the video is buffered.
  final Duration buffered;

  /// The size of the video in pixels.
  final Size size;

  /// Width over height, or 1 while unknown.
  double get aspectRatio {
    if (!isInitialized || size.width <= 0 || size.height <= 0) return 1;
    return size.width / size.height;
  }

  /// A copy with the given fields replaced.
  VideoPlayerValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    Size? size,
  }) => VideoPlayerValue(
    isInitialized: isInitialized ?? this.isInitialized,
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    size: size ?? this.size,
  );
}

/// Plays a video in an HTML video element, used in WebAssembly builds in
/// place of `video_player`.
class VideoPlayerController extends ValueNotifier<VideoPlayerValue> {
  /// Plays the video at [url].
  VideoPlayerController.networkUrl(Uri url) : this._(url.toString());

  /// Plays [file]; on the web its path is a `blob:` URL.
  VideoPlayerController.file(File file) : this._(file.path);

  VideoPlayerController._(this._source) : super(const VideoPlayerValue());

  static var _count = 0;

  final String _source;
  final _element = web.HTMLVideoElement();

  /// The platform view that shows the video.
  final String viewType = 'flutter_chat_pro_video_${_count++}';

  Future<void>? _initialized;

  /// Loads the metadata; completes with an error when the video can't play.
  Future<void> initialize() => _initialized ??= _initialize();

  Future<void> _initialize() {
    final loaded = Completer<void>();
    _element
      ..src = _source
      ..preload = 'auto'
      ..playsInline = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      // Taps go to the Flutter widgets above the video.
      ..style.pointerEvents = 'none';
    _on('loadedmetadata', () {
      value = value.copyWith(
        isInitialized: true,
        duration: _toDuration(_element.duration),
        size: Size(
          _element.videoWidth.toDouble(),
          _element.videoHeight.toDouble(),
        ),
      );
      if (!loaded.isCompleted) loaded.complete();
    });
    _on('error', () {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('The video could not be loaded'));
      }
    });
    _on('timeupdate', () {
      value = value.copyWith(position: _toDuration(_element.currentTime));
    });
    _on('progress', () {
      final ranges = _element.buffered;
      if (ranges.length > 0) {
        value = value.copyWith(
          buffered: _toDuration(ranges.end(ranges.length - 1)),
        );
      }
    });
    _on('play', () => value = value.copyWith(isPlaying: true));
    _on('pause', () => value = value.copyWith(isPlaying: false));
    _on('ended', () => value = value.copyWith(isPlaying: false));
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int _) => _element,
    );
    _element.load();
    return loaded.future;
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    await _element.play().toDart;
  }

  /// Pauses playback.
  Future<void> pause() async => _element.pause();

  /// Moves playback to [position].
  Future<void> seekTo(Duration position) async {
    _element.currentTime =
        position.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  Future<void> dispose() async {
    _element
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  void _on(String type, void Function() handler) {
    _element.addEventListener(type, ((web.Event _) => handler()).toJS);
  }

  static Duration _toDuration(num seconds) => seconds.isFinite
      ? Duration(
          microseconds: (seconds * Duration.microsecondsPerSecond).round(),
        )
      : Duration.zero;
}

/// Shows the video of [controller].
class VideoPlayer extends StatelessWidget {
  /// A view of [controller]'s video.
  const VideoPlayer(this.controller, {super.key});

  /// The video to show.
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) =>
      HtmlElementView(viewType: controller.viewType);
}

/// Colors of a [VideoProgressIndicator].
@immutable
class VideoProgressColors {
  /// The colors; the defaults match `video_player`.
  const VideoProgressColors({
    this.playedColor = const Color.fromRGBO(255, 0, 0, 0.7),
    this.bufferedColor = const Color.fromRGBO(50, 50, 200, 0.2),
    this.backgroundColor = const Color.fromRGBO(200, 200, 200, 0.5),
  });

  /// The part already played.
  final Color playedColor;

  /// The part buffered but not played.
  final Color bufferedColor;

  /// The rest of the bar.
  final Color backgroundColor;
}

/// A bar with the played and buffered parts of [controller]'s video.
class VideoProgressIndicator extends StatelessWidget {
  /// A bar for [controller]; with [allowScrubbing] a tap or drag seeks.
  const VideoProgressIndicator(
    this.controller, {
    required this.allowScrubbing,
    this.colors = const VideoProgressColors(),
    this.padding = const EdgeInsets.only(top: 5),
    super.key,
  });

  /// The video whose progress shows.
  final VideoPlayerController controller;

  /// Whether a tap or drag on the bar seeks.
  final bool allowScrubbing;

  /// The bar colors.
  final VideoProgressColors colors;

  /// Space around the bar.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset local) {
          final total = controller.value.duration;
          if (total <= Duration.zero || constraints.maxWidth <= 0) return;
          final fraction = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          unawaited(controller.seekTo(total * fraction));
        }

        final bar = ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final total = value.duration.inMicroseconds;
            double part(Duration d) =>
                total <= 0 ? 0 : (d.inMicroseconds / total).clamp(0.0, 1.0);
            return Padding(
              padding: padding,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  LinearProgressIndicator(
                    value: part(value.buffered),
                    valueColor: AlwaysStoppedAnimation(colors.bufferedColor),
                    backgroundColor: colors.backgroundColor,
                  ),
                  LinearProgressIndicator(
                    value: part(value.position),
                    valueColor: AlwaysStoppedAnimation(colors.playedColor),
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            );
          },
        );
        if (!allowScrubbing) return bar;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition),
          onHorizontalDragUpdate: (d) => seek(d.localPosition),
          child: bar,
        );
      },
    );
  }
}
