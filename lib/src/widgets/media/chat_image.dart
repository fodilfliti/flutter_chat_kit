import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/media/chat_media_store.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/widgets/media/chat_media_scope.dart';

/// An attachment image that fills its box.
///
/// Sources, in order: the local file of a message being sent, the copy in
/// the media store, else a download into the store (immediately for kinds in
/// `ChatMediaScope.autoDownload`, else on tap). On the web, and without a
/// store, the URL loads through `CachedNetworkImage`. Decoding is sized to
/// the box and the device pixel ratio.
class ChatImage extends StatefulWidget {
  const ChatImage({
    required this.attachment,
    this.fit = BoxFit.cover,
    this.thumbnail = false,
    this.strings = const ChatStrings(),
    this.store,
    this.autoDownload,
    super.key,
  });

  final Attachment attachment;
  final BoxFit fit;

  /// Shows the thumbnail (for video posters and grid cells) instead of the
  /// full image: the poster made on this device (`thumbnailPath`) while
  /// sending, else `thumbnailUrl`. Without either a video shows the
  /// placeholder.
  final bool thumbnail;
  final ChatStrings strings;

  /// Defaults to `ChatMediaScope.of(context).store`.
  final ChatMediaStore? store;

  /// Defaults to whether the scope auto-downloads this kind.
  final bool? autoDownload;

  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  ImageProvider? _provider;
  String? _resolvedFor;
  bool _failed = false;
  bool _waitingForTap = false;
  ChatMediaStore? _store;

  String? get _url {
    final a = widget.attachment;
    if (widget.thumbnail) {
      return a.thumbnailUrl ??
          (a.kind == AttachmentKind.image ? a.remoteUrl : null);
    }
    return a.remoteUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment != widget.attachment ||
        oldWidget.thumbnail != widget.thumbnail ||
        oldWidget.store != widget.store) {
      _resolve();
    }
  }

  void _resolve() {
    final scope = ChatMediaScope.of(context);
    final store = widget.store ?? scope.store;
    final a = widget.attachment;
    final poster = widget.thumbnail ? a.thumbnailPath : null;
    final key = '${a.localPath}|$poster|$_url|${identityHashCode(store)}';
    if (key == _resolvedFor) return;
    _resolvedFor = key;
    _store = store;
    _failed = false;
    _waitingForTap = false;
    _provider = null;

    final local = a.localPath;
    if (!kIsWeb &&
        local != null &&
        (!widget.thumbnail || a.kind == AttachmentKind.image) &&
        File(local).existsSync()) {
      _provider = FileImage(File(local));
      return;
    }
    if (poster != null) {
      if (kIsWeb) {
        _provider = NetworkImage(poster);
        return;
      }
      if (File(poster).existsSync()) {
        _provider = FileImage(File(poster));
        return;
      }
    }
    final url = _url;
    if (url == null) return;
    if (store == null || !store.isSupported) {
      // The errorBuilder shows the failure; the listener keeps it out of
      // the error log.
      _provider = CachedNetworkImageProvider(url, errorListener: (_) {});
      return;
    }
    final known = store.peek(url);
    if (known != null) {
      _provider = FileImage(known);
      return;
    }
    final auto = widget.autoDownload ?? scope.autoDownload.contains(a.kind);
    unawaited(_load(store, url, download: auto || widget.thumbnail, key: key));
  }

  Future<void> _load(
    ChatMediaStore store,
    String url, {
    required bool download,
    required String key,
  }) async {
    try {
      final file =
          await store.file(url) ?? (download ? await store.fetch(url) : null);
      if (!mounted || _resolvedFor != key) return;
      setState(() {
        if (file != null) {
          _provider = FileImage(file);
        } else {
          _waitingForTap = true;
        }
      });
    } on Object {
      if (!mounted || _resolvedFor != key) return;
      setState(() => _failed = true);
    }
  }

  void _retry() {
    final store = _store;
    final url = _url;
    final key = _resolvedFor;
    if (store == null || url == null || key == null) return;
    setState(() {
      _failed = false;
      _waitingForTap = false;
    });
    unawaited(_load(store, url, download: true, key: key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final placeholder = ColoredBox(
      color: theme.incomingBubble.color,
      child: const SizedBox.expand(),
    );
    final provider = _provider;
    if (provider != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
          final width = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * dpr).round()
              : null;
          return Image(
            image: ResizeImage.resizeIfNeeded(width, null, provider),
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) {
              if (sync || frame != null) return child;
              return placeholder;
            },
            errorBuilder: (context, error, stack) =>
                _icon(theme, Icons.broken_image_outlined, placeholder),
          );
        },
      );
    }
    if (_failed) {
      return _button(
        theme,
        placeholder,
        Icons.refresh,
        widget.strings.downloadFailed,
      );
    }
    if (_waitingForTap) {
      return _button(
        theme,
        placeholder,
        Icons.download_outlined,
        widget.strings.download,
      );
    }
    final url = _url;
    final store = _store;
    if (url == null || store == null || !store.isSupported) {
      return widget.thumbnail
          ? _icon(theme, Icons.videocam_outlined, placeholder)
          : placeholder;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        Center(
          child: ValueListenableBuilder<double?>(
            valueListenable: store.downloadProgress(url),
            builder: (context, value, _) => SizedBox.square(
              dimension: theme.size(28),
              child: CircularProgressIndicator(
                value: value == null || value <= 0 ? null : value,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _icon(ChatTheme theme, IconData icon, Widget placeholder) {
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        Center(
          child: Icon(icon, color: theme.iconColor, size: theme.size(24)),
        ),
      ],
    );
  }

  Widget _button(
    ChatTheme theme,
    Widget placeholder,
    IconData icon,
    String label,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        Center(
          child: IconButton.filledTonal(
            onPressed: _retry,
            tooltip: label,
            iconSize: theme.size(24),
            icon: Icon(icon),
          ),
        ),
      ],
    );
  }
}
