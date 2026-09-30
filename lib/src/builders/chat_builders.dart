import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/typing.dart';

/// Wraps or replaces a default widget.
typedef DefaultChildBuilder =
    Widget Function(BuildContext context, Widget defaultChild);

/// Wraps or replaces the default rendering of a message part.
typedef MessageWidgetBuilder =
    Widget Function(
      BuildContext context,
      MessageContext message,
      Widget defaultChild,
    );

/// Renders a `CustomMessage` (or an unknown type) that has no default.
typedef CustomMessageBuilder =
    Widget Function(BuildContext context, MessageContext message);

/// Renders any `CustomMessage` not in `ChatBuilders.customBuilders`, for
/// example by reading a variant from its data; null shows the unsupported
/// view.
typedef CustomMessageResolver =
    Widget? Function(BuildContext context, MessageContext message);

/// Edits the long-press action list; return [defaults] to keep them.
typedef MessageActionsBuilder =
    List<MessageAction> Function(
      BuildContext context,
      MessageContext message,
      List<MessageAction> defaults,
    );

typedef DateSeparatorBuilder =
    Widget Function(BuildContext context, DateTime day, Widget defaultChild);

typedef TypingIndicatorBuilder =
    Widget Function(
      BuildContext context,
      TypingState typing,
      List<ChatUser> users,
      Widget defaultChild,
    );

typedef ScrollToBottomBuilder =
    Widget Function(
      BuildContext context,
      int unreadCount,
      VoidCallback onPressed,
      Widget defaultChild,
    );

typedef ChatErrorBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      VoidCallback retry,
      Widget defaultChild,
    );

typedef AppBarBuilder =
    PreferredSizeWidget Function(
      BuildContext context,
      ChatRoom? room,
      PreferredSizeWidget defaultAppBar,
    );

/// Extra widgets (usually `IconButton`s) for the default app bar.
typedef AppBarActionsBuilder =
    List<Widget> Function(BuildContext context, ChatRoom? room);

/// One entry of a message's long-press menu.
@immutable
class MessageAction {
  const MessageAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  static const replyId = 'reply';
  static const copyId = 'copy';
  static const editId = 'edit';
  static const deleteId = 'delete';
  static const retryId = 'retry';
  static const selectId = 'select';

  /// Stable id; the defaults use the `*Id` constants.
  final String id;
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTap;
  final bool isDestructive;
}

/// Customization hooks for the chat room. Each builder receives the
/// default widget so it can wrap it instead of rebuilding it.
@immutable
class ChatBuilders {
  const ChatBuilders({
    this.messageBuilder,
    this.bubbleBuilder,
    this.textBuilder,
    this.imageBuilder,
    this.videoBuilder,
    this.audioBuilder,
    this.fileBuilder,
    this.systemBuilder,
    this.deletedBuilder,
    this.unsupportedBuilder,
    this.customBuilders = const {},
    this.customBuilder,
    this.bubbledCustomTypes = const {},
    this.avatarBuilder,
    this.authorNameBuilder,
    this.statusBuilder,
    this.timestampBuilder,
    this.replyPreviewBuilder,
    this.reactionsBuilder,
    this.dateSeparatorBuilder,
    this.unreadDividerBuilder,
    this.typingBuilder,
    this.scrollToBottomBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.composerBuilder,
    this.appBarBuilder,
    this.appBarActions,
    this.messageActions,
  });

  /// The whole row: avatar, name, bubble, reactions.
  final MessageWidgetBuilder? messageBuilder;

  /// The bubble shape around the content.
  final MessageWidgetBuilder? bubbleBuilder;
  final MessageWidgetBuilder? textBuilder;
  final MessageWidgetBuilder? imageBuilder;
  final MessageWidgetBuilder? videoBuilder;
  final MessageWidgetBuilder? audioBuilder;
  final MessageWidgetBuilder? fileBuilder;
  final MessageWidgetBuilder? systemBuilder;
  final MessageWidgetBuilder? deletedBuilder;

  /// A `CustomMessage` that neither [customBuilders] nor [customBuilder]
  /// renders.
  final MessageWidgetBuilder? unsupportedBuilder;

  /// Renderers for `CustomMessage.customType`, for example `'offer'`.
  final Map<String, CustomMessageBuilder> customBuilders;

  /// Fallback for custom messages without an entry in [customBuilders]:
  /// one place to dispatch many types or variants.
  final CustomMessageResolver? customBuilder;

  /// Custom types drawn inside the default bubble, with the reply preview,
  /// time and status ticks. Other custom types render bare.
  final Set<String> bubbledCustomTypes;
  final MessageWidgetBuilder? avatarBuilder;
  final MessageWidgetBuilder? authorNameBuilder;
  final MessageWidgetBuilder? statusBuilder;
  final MessageWidgetBuilder? timestampBuilder;
  final MessageWidgetBuilder? replyPreviewBuilder;
  final MessageWidgetBuilder? reactionsBuilder;
  final DateSeparatorBuilder? dateSeparatorBuilder;
  final DefaultChildBuilder? unreadDividerBuilder;
  final TypingIndicatorBuilder? typingBuilder;
  final ScrollToBottomBuilder? scrollToBottomBuilder;
  final DefaultChildBuilder? emptyBuilder;
  final DefaultChildBuilder? loadingBuilder;
  final ChatErrorBuilder? errorBuilder;
  final DefaultChildBuilder? composerBuilder;

  /// Replaces or wraps the whole app bar.
  final AppBarBuilder? appBarBuilder;

  /// Adds actions to the default app bar.
  final AppBarActionsBuilder? appBarActions;
  final MessageActionsBuilder? messageActions;
}
