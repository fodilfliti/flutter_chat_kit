import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/builders/chat_builders.dart';
import 'package:flutter_chat_pro/src/config/chat_config.dart';
import 'package:flutter_chat_pro/src/config/chat_formatters.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_pro/src/controllers/composer_controller.dart';
import 'package:flutter_chat_pro/src/media/default_pickers.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/widgets/common/chat_style.dart';
import 'package:flutter_chat_pro/src/widgets/composer/attachment_sheet.dart';
import 'package:flutter_chat_pro/src/widgets/composer/chat_composer.dart';
import 'package:flutter_chat_pro/src/widgets/messages/text_message_view.dart';
import 'package:flutter_chat_pro/src/widgets/room/chat_app_bar.dart';
import 'package:flutter_chat_pro/src/widgets/room/message_content.dart';
import 'package:flutter_chat_pro/src/widgets/room/message_list.dart';
import 'package:flutter_chat_pro/src/widgets/room/selection_app_bar.dart';

/// Wraps or replaces the room app bar; return null to hide it.
typedef ChatRoomAppBarBuilder =
    PreferredSizeWidget? Function(
      BuildContext context,
      ChatRoomController room,
      PreferredSizeWidget defaultAppBar,
    );

/// A complete room screen: [ChatAppBar] (or [SelectionAppBar] while
/// selecting), an optional [header], [ChatMessageList] and [ChatComposer].
///
/// Creates and disposes its own [ComposerController] unless [composer] is
/// given. The room [controller] belongs to the caller. The view never
/// navigates; taps are reported through callbacks.
///
/// ```dart
/// class _RoomPageState extends State<RoomPage> {
///   late final room = widget.kit.room(widget.roomId);
///
///   @override
///   Widget build(BuildContext context) => ChatRoomView(controller: room);
///
///   @override
///   void dispose() {
///     room.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// See doc/customization.md for builders, styles and strings.
class ChatRoomView extends StatefulWidget {
  /// A room screen for [controller]. Only [controller] is required; every
  /// other parameter has a working default.
  const ChatRoomView({
    required this.controller,
    this.composer,
    this.appBar = const ChatAppBarOptions(),
    this.appBarBuilder,
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
    this.enableVoice = true,
    this.enableAttachments = true,
    this.onForward,
    this.background,
    this.backgroundColor,
    super.key,
  });

  /// The room shown, from `ChatKit.room`. The caller disposes it.
  final ChatRoomController controller;

  /// The text field's state (draft, reply, edit). Pass one to control the
  /// composer from outside, for example to prefill text. Defaults to one
  /// owned by the view.
  final ComposerController? composer;

  /// Actions, title tap, builders and color of the room app bar. Defaults
  /// to avatar, room name and subtitle with a back button.
  final ChatAppBarOptions appBar;

  /// Applied last, to either bar; can hide it. `ChatBuilders.appBarBuilder`
  /// and `appBarActions` apply to the room bar only.
  final ChatRoomAppBarBuilder? appBarBuilder;

  /// Also used for `appBarActions`, `appBarBuilder` and `composerBuilder`.
  final ChatBuilders builders;

  /// Applied to this screen only; defaults to the ambient `ChatTheme`. The
  /// scale of a surrounding `ChatStyle` still applies.
  final ChatTheme? theme;

  /// Defaults to the kit's config.
  final ChatConfig? config;

  /// Every visible text (English by default); override for translations.
  final ChatStrings strings;

  /// Times, dates, file sizes and durations shown in the room.
  final ChatFormatters formatters;

  /// Shown between the app bar and the messages, such as a pinned message
  /// or a banner.
  final Widget? header;

  /// Called with the tapped message. Null: a tap does nothing (long press
  /// still opens the actions sheet). While selecting, taps toggle the
  /// selection instead.
  final MessageCallback? onMessageTap;

  /// Called with the author id when an avatar next to a message is tapped,
  /// for example to open a profile. Null: avatars are not tappable.
  final ValueChanged<String>? onAvatarTap;

  /// Called with the `https:`, `mailto:` or `tel:` URI of a tapped link,
  /// usually to launch it. Null: links are styled but not tappable.
  final LinkTapCallback? onLinkTap;

  /// Replaces opening the media viewer or saving the file.
  final AttachmentTapCallback? onAttachmentTap;

  /// Picks files when an attachment sheet option with a source is chosen.
  /// Defaults to `DefaultAttachmentPicker` (`image_picker` and
  /// `file_picker`).
  final AttachmentPicker? onAttachmentPick;

  /// App options added after camera, gallery, video and file in the
  /// attachment sheet, such as "Location" or "Offer". Empty by default.
  final List<AttachmentOption> extraAttachmentOptions;

  /// Shows the hold-to-record mic. Voice also needs a `ChatKit.uploader`.
  final bool enableVoice;

  /// Shows the attach button. Attachments also need a `ChatKit.uploader`.
  final bool enableAttachments;

  /// Enables the forward action of the selection app bar.
  final ValueChanged<List<Message>>? onForward;

  /// Painted behind the messages, such as a wallpaper; replaces
  /// `ChatMessageListStyle.background`.
  final Widget? background;

  /// Color of the whole screen behind the list and the composer. Defaults
  /// to the `Scaffold` background of the app theme.
  final Color? backgroundColor;

  @override
  State<ChatRoomView> createState() => ChatRoomViewState();
}

/// State of [ChatRoomView]. Reach it with a `GlobalKey` to use the
/// [composer] the view created.
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
    final scale = ChatStyle.scaleOf(context);
    final scaled = scale.isNone
        ? chatTheme
        : chatTheme.scaled(scale.size, textFactor: scale.text);
    return Theme(
      data: base.copyWith(extensions: [...base.extensions.values, scaled]),
      child: child,
    );
  }

  Widget _build(BuildContext context, Widget? _) {
    final c = widget.controller;
    final composer = this.composer;
    final selecting = c.selectedIds.isNotEmpty;

    final builders = widget.builders;
    final PreferredSizeWidget defaultBar;
    if (selecting) {
      defaultBar = SelectionAppBar(
        controller: c,
        onForward: widget.onForward,
        backgroundColor: widget.appBar.backgroundColor,
        strings: widget.strings,
      );
    } else {
      final extra = builders.appBarActions?.call(context, c.room);
      final bar = ChatAppBar(
        controller: c,
        options: extra == null
            ? widget.appBar
            : widget.appBar.copyWith(
                actions: [...widget.appBar.actions, ...extra],
              ),
        strings: widget.strings,
        formatters: widget.formatters,
      );
      defaultBar = builders.appBarBuilder?.call(context, c.room, bar) ?? bar;
    }
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
    } else if (ChatTheme.of(context).messageList.background
        case final decoration?) {
      list = DecoratedBox(decoration: decoration, child: list);
    }

    Widget input = ChatComposer(
      controller: composer,
      onAttachmentPick: widget.onAttachmentPick,
      extraAttachmentOptions: widget.extraAttachmentOptions,
      enableVoice: widget.enableVoice,
      enableAttachments: widget.enableAttachments,
      strings: widget.strings,
      formatters: widget.formatters,
    );
    if (builders.composerBuilder case final build?) {
      input = build(context, input);
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
