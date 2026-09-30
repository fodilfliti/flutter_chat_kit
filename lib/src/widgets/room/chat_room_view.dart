import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/config/chat_config.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_kit/src/controllers/composer_controller.dart';
import 'package:flutter_chat_kit/src/media/default_pickers.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/widgets/composer/attachment_sheet.dart';
import 'package:flutter_chat_kit/src/widgets/composer/chat_composer.dart';
import 'package:flutter_chat_kit/src/widgets/messages/text_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/room/chat_app_bar.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_content.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_list.dart';
import 'package:flutter_chat_kit/src/widgets/room/selection_app_bar.dart';

/// Wraps or replaces the room app bar; return null to hide it.
typedef ChatRoomAppBarBuilder =
    PreferredSizeWidget? Function(
      BuildContext context,
      ChatRoomController room,
      PreferredSizeWidget defaultAppBar,
    );

/// Wraps or replaces the composer.
typedef ChatComposerBuilder =
    Widget Function(
      BuildContext context,
      ComposerController composer,
      Widget defaultChild,
    );

/// A complete room screen: [ChatAppBar] (or [SelectionAppBar] while
/// selecting), an optional [header], [ChatMessageList] and [ChatComposer].
///
/// Creates and disposes its own [ComposerController] unless [composer] is
/// given. The room [controller] belongs to the caller. The view never
/// navigates; taps are reported through callbacks.
class ChatRoomView extends StatefulWidget {
  const ChatRoomView({
    required this.controller,
    this.composer,
    this.appBar = const ChatAppBarOptions(),
    this.appBarBuilder,
    this.composerBuilder,
    this.builders = const ChatBuilders(),
    this.theme,
    this.config,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.header,
    this.onMessageTap,
    this.onAvatarTap,
    this.onLinkTap,
    this.onAttachmentTap,
    this.onAttachmentPick,
    this.extraAttachmentOptions = const [],
    this.onForward,
    this.background,
    this.backgroundColor,
    super.key,
  });

  final ChatRoomController controller;

  /// Defaults to one owned by the view.
  final ComposerController? composer;
  final ChatAppBarOptions appBar;
  final ChatRoomAppBarBuilder? appBarBuilder;
  final ChatComposerBuilder? composerBuilder;
  final ChatBuilders builders;

  /// Applied to this screen only; defaults to the ambient `ChatTheme`.
  final ChatTheme? theme;

  /// Defaults to the kit's config.
  final ChatConfig? config;
  final ChatStrings strings;
  final ChatFormatters formatters;

  /// Shown between the app bar and the messages, such as a pinned message
  /// or a banner.
  final Widget? header;
  final MessageCallback? onMessageTap;
  final ValueChanged<String>? onAvatarTap;
  final LinkTapCallback? onLinkTap;

  /// Replaces opening the media viewer or saving the file.
  final AttachmentTapCallback? onAttachmentTap;
  final AttachmentPicker? onAttachmentPick;
  final List<AttachmentOption> extraAttachmentOptions;

  /// Enables the forward action of the selection app bar.
  final ValueChanged<List<Message>>? onForward;

  /// Painted behind the messages, such as a wallpaper.
  final Widget? background;
  final Color? backgroundColor;

  @override
  State<ChatRoomView> createState() => ChatRoomViewState();
}

class ChatRoomViewState extends State<ChatRoomView> {
  ComposerController? _ownComposer;

  /// The composer in use (the given one or the view's own).
  ComposerController get composer =>
      widget.composer ??
      (_ownComposer ??= ComposerController(widget.controller));

  @override
  void didUpdateWidget(ChatRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final roomChanged = !identical(oldWidget.controller, widget.controller);
    if (widget.composer != null || roomChanged) {
      _ownComposer?.dispose();
      _ownComposer = null;
    }
  }

  @override
  void dispose() {
    _ownComposer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = widget.theme;
    final child = ListenableBuilder(
      listenable: widget.controller,
      builder: _build,
    );
    if (chatTheme == null) return child;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(extensions: [...base.extensions.values, chatTheme]),
      child: child,
    );
  }

  Widget _build(BuildContext context, Widget? _) {
    final c = widget.controller;
    final composer = this.composer;
    final selecting = c.selectedIds.isNotEmpty;

    final defaultBar = selecting
        ? SelectionAppBar(
            controller: c,
            onForward: widget.onForward,
            backgroundColor: widget.appBar.backgroundColor,
            strings: widget.strings,
          )
        : ChatAppBar(
            controller: c,
            options: widget.appBar,
            strings: widget.strings,
            formatters: widget.formatters,
          );
    final appBar = widget.appBarBuilder == null
        ? defaultBar
        : widget.appBarBuilder!(context, c, defaultBar);

    Widget list = ChatMessageList(
      controller: c,
      builders: widget.builders,
      config: widget.config,
      strings: widget.strings,
      formatters: widget.formatters,
      onMessageTap: widget.onMessageTap,
      onAvatarTap: widget.onAvatarTap,
      onReply: (message) => composer.reply(message.message),
      onEdit: (message) => composer.startEdit(message.message),
      onLinkTap: widget.onLinkTap,
      onAttachmentTap: widget.onAttachmentTap,
      enableSelection: true,
    );
    if (widget.background case final background?) {
      list = Stack(
        children: [
          Positioned.fill(child: background),
          list,
        ],
      );
    }

    Widget input = ChatComposer(
      controller: composer,
      onAttachmentPick: widget.onAttachmentPick,
      extraAttachmentOptions: widget.extraAttachmentOptions,
      strings: widget.strings,
      formatters: widget.formatters,
    );
    if (widget.composerBuilder case final build?) {
      input = build(context, composer, input);
    }

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.clearSelection();
      },
      child: Scaffold(
        appBar: appBar,
        backgroundColor: widget.backgroundColor,
        body: Column(
          children: [
            ?widget.header,
            Expanded(child: list),
            input,
          ],
        ),
      ),
    );
  }
}
