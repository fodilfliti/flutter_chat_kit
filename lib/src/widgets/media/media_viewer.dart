import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/controllers/audio_player_hub.dart';
import 'package:flutter_chat_kit/src/media/chat_media_store.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_image.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_media_scope.dart';
import 'package:video_player/video_player.dart';

/// One page of the [MediaViewer].
@immutable
class MediaItem {
  const MediaItem({required this.attachment, this.heroTag, this.messageId});

  final Attachment attachment;

  /// Matches the tag of the bubble cell for the open / close animation.
  final Object? heroTag;

  /// Local id of the message it belongs to.
  final String? messageId;
}

/// Full-screen images and videos: swipe between [items], pinch or
/// double-tap to zoom, swipe down to close, and save to the device.
///
/// Pushed routes do not see the room's `ChatMediaScope`, so [store] is
/// passed explicitly ([show] reads it from the calling context).
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    required this.items,
    this.initialIndex = 0,
    this.store,
    this.strings = const ChatStrings(),
    this.videoControllerFactory,
    super.key,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final ChatMediaStore? store;
  final ChatStrings strings;

  /// Builds video controllers; replaced in tests.
  final VideoPlayerController Function(Attachment attachment, File? file)?
  videoControllerFactory;

  /// Opens the viewer over [items] at [initialIndex], pausing voice
  /// playback.
  static Future<void> show(
    BuildContext context, {
    required List<MediaItem> items,
    int initialIndex = 0,
    ChatStrings strings = const ChatStrings(),
    ChatMediaStore? store,
    AudioPlayerHub? audio,
  }) {
    final scope = ChatMediaScope.of(context);
    unawaited((audio ?? scope.audio)?.pause());
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: MediaViewer(
            items: items,
            initialIndex: initialIndex,
            store: store ?? scope.store,
            strings: strings,
          ),
        ),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _pages = PageController(initialPage: _initial);
  late int _index = _initial;
  bool _zoomed = false;
  double _drag = 0;
  bool _saving = false;

  int get _initial =>
      widget.initialIndex.clamp(0, (widget.items.length - 1).clamp(0, 1 << 30));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _canSave {
    final store = widget.store;
    final url = widget.items.isEmpty
        ? null
        : widget.items[_index].attachment.remoteUrl;
    return store != null && store.isSupported && url != null;
  }

  Future<void> _save() async {
    final store = widget.store;
    final a = widget.items[_index].attachment;
    final url = a.remoteUrl;
    if (store == null || url == null || _saving) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    bool saved;
    try {
      saved = await store.save(url, name: a.name, mimeType: a.mimeType);
    } on Object {
      saved = false;
      messenger?.showSnackBar(
        SnackBar(content: Text(widget.strings.downloadFailed)),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      messenger?.showSnackBar(SnackBar(content: Text(widget.strings.saved)));
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_zoomed) return;
    setState(() => _drag += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_zoomed) return;
    final velocity = d.primaryVelocity ?? 0;
    if (_drag.abs() > 120 || velocity.abs() > 900) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final height = MediaQuery.sizeOf(context).height;
    final fade = (1 - (_drag.abs() / (height / 2))).clamp(0.0, 1.0);
    final strings = widget.strings;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4 * fade),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: strings.close,
          icon: const Icon(Icons.close),
        ),
        title: items.length > 1
            ? Text(strings.mediaPosition(_index + 1, items.length))
            : null,
        actions: [
          if (_canSave && _saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (_canSave)
            IconButton(
              onPressed: () => unawaited(_save()),
              tooltip: strings.save,
              icon: const Icon(Icons.download_outlined),
            ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
        onVerticalDragEnd: _zoomed ? null : _onDragEnd,
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: PageView.builder(
            controller: _pages,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (context, i) {
              final item = items[i];
              final Widget page = item.attachment.kind == AttachmentKind.video
                  ? _VideoPage(
                      attachment: item.attachment,
                      store: widget.store,
                      active: i == _index,
                      strings: strings,
                      factory: widget.videoControllerFactory,
                    )
                  : _ImagePage(
                      attachment: item.attachment,
                      store: widget.store,
                      strings: strings,
                      onZoomChanged: (zoomed) {
                        if (zoomed != _zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      },
                    );
              final tag = item.heroTag;
              return tag == null ? page : Hero(tag: tag, child: page);
            },
          ),
        ),
      ),
    );
  }
}

class _ImagePage extends StatefulWidget {
  const _ImagePage({
    required this.attachment,
    required this.store,
    required this.strings,
    required this.onZoomChanged,
  });

  final Attachment attachment;
  final ChatMediaStore? store;
  final ChatStrings strings;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoomAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onAnimate);
  Animation<Matrix4>? _tween;
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _zoomAnimation.dispose();
    super.dispose();
  }

  void _onAnimate() {
    final tween = _tween;
    if (tween != null) _transform.value = tween.value;
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _toggleZoom() {
    final end = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(
              -_doubleTapAt.dx * 1.5,
              -_doubleTapAt.dy * 1.5,
              0,
              1,
            )
            ..scaleByDouble(2.5, 2.5, 1, 1));
    _tween = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOutCubic),
    );
    _zoomAnimation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        panEnabled: _zoomed,
        maxScale: 5,
        child: SizedBox.expand(
          child: ChatImage(
            attachment: widget.attachment,
            fit: BoxFit.contain,
            store: widget.store,
            autoDownload: true,
            strings: widget.strings,
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.attachment,
    required this.store,
    required this.active,
    required this.strings,
    this.factory,
  });

  final Attachment attachment;
  final ChatMediaStore? store;
  final bool active;
  final ChatStrings strings;
  final VideoPlayerController Function(Attachment attachment, File? file)?
  factory;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_open());
  }

  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (widget.active && controller == null && !_failed) {
      unawaited(_open());
    } else if (!widget.active && controller != null) {
      unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<File?> _localFile() async {
    final a = widget.attachment;
    final local = a.localPath;
    if (!kIsWeb && local != null && File(local).existsSync()) {
      return File(local);
    }
    final url = a.remoteUrl;
    final store = widget.store;
    if (url == null || store == null || !store.isSupported) return null;
    return store.peek(url) ?? await store.file(url);
  }

  Future<void> _open() async {
    try {
      final file = await _localFile();
      if (!mounted) return;
      final a = widget.attachment;
      final url = a.remoteUrl;
      final VideoPlayerController controller;
      final factory = widget.factory;
      if (factory != null) {
        controller = factory(a, file);
      } else if (file != null) {
        controller = VideoPlayerController.file(file);
      } else if (url != null) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        final store = widget.store;
        // Streams now and keeps a copy for next time.
        if (store != null && store.isSupported) {
          unawaited(store.fetch(url).then((_) {}, onError: (Object _) {}));
        }
      } else {
        throw StateError('Video without a source');
      }
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      if (widget.active) await controller.play();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toggle(VideoPlayerController controller) {
    unawaited(
      controller.value.isPlaying ? controller.pause() : controller.play(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return Center(
        child: IconButton.filledTonal(
          onPressed: () {
            setState(() => _failed = false);
            unawaited(_open());
          },
          tooltip: widget.strings.downloadFailed,
          icon: const Icon(Icons.refresh),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ChatImage(
            attachment: widget.attachment,
            thumbnail: true,
            fit: BoxFit.contain,
            store: widget.store,
            strings: widget.strings,
          ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    return GestureDetector(
      onTap: () => _toggle(controller),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => AnimatedOpacity(
              opacity: value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Semantics(
                button: true,
                label: value.isPlaying
                    ? widget.strings.pause
                    : widget.strings.play,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
