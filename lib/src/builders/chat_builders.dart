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

/// Wraps or replaces the day label between messages; [day] is the local
/// date at midnight.
typedef DateSeparatorBuilder =
    Widget Function(BuildContext context, DateTime day, Widget defaultChild);

/// Wraps or replaces the typing indicator at the bottom of the list.
/// [users] are the resolved members in `typing.userIds`; unresolved ones
/// are missing.
typedef TypingIndicatorBuilder =
    Widget Function(
      BuildContext context,
      TypingState typing,
      List<ChatUser> users,
      Widget defaultChild,
    );

/// Wraps or replaces the "scroll to bottom" button shown when the list is
/// scrolled up. [unreadCount] counts messages from others that arrived
/// meanwhile; [onPressed] scrolls down.
typedef ScrollToBottomBuilder =
    Widget Function(
      BuildContext context,
      int unreadCount,
      VoidCallback onPressed,
      Widget defaultChild,
    );

/// Wraps or replaces an error state. [error] is usually an `AppFailure`;
/// [retry] tries the failed load again.
typedef ChatErrorBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      VoidCallback retry,
      Widget defaultChild,
    );

/// Wraps or replaces the room app bar. [room] is null until the room is
/// cached.
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
///
/// ```dart
/// messageActions: (context, m, defaults) => [
///   ...defaults.where((a) => a.id != MessageAction.copyId),
///   MessageAction(
///     id: 'report',
///     label: 'Report',
///     icon: Icons.flag_outlined,
///     onTap: () => reportMessage(m.message.id),
///   ),
/// ],
/// ```
@immutable
class MessageAction {
  /// An entry labeled [label] with [icon] that runs [onTap].
  const MessageAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  /// Id of the default "Reply" action (sent messages only).
  static const replyId = 'reply';

  /// Id of the default "Copy" action (messages with text or a caption).
  static const copyId = 'copy';

  /// Id of the default "Edit" action (own sent text, image or video).
  static const editId = 'edit';

  /// Id of the default "Delete" action (own messages).
  static const deleteId = 'delete';

  /// Id of the default "Retry" action (own failed messages).
  static const retryId = 'retry';

  /// Id of the default "Select" action, which starts multi-selection.
  static const selectId = 'select';

  /// Stable id; the defaults use the `*Id` constants.
  final String id;

  /// Text of the entry.
  final String label;

  /// Icon before [label].
  final IconData icon;

  /// Runs after the sheet closes.
  final FutureOr<void> Function() onTap;

  /// Draws the entry in the failed-status color, as for delete. Defaults
  /// to false.
  final bool isDestructive;
}

/// Customization hooks for the chat room. Each builder receives the
/// default widget so it can wrap it instead of rebuilding it.
///
/// Every builder is optional; null keeps the default. Pass it as
/// `ChatRoomView.builders`. See doc/customization.md.
///
/// ```dart
/// ChatBuilders(
///   customBuilders: {'offer': (context, m) => OfferCard(m)},
///   bubbleBuilder: (context, m, bubble) => m.isHighlighted
///       ? ColoredBox(color: Colors.amber, child: bubble)
///       : bubble,
/// )
/// ```
@immutable
class ChatBuilders {
  /// Hooks for the room; all null by default.
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

  /// The text of a `TextMessage`, with links and "read more".
  final MessageWidgetBuilder? textBuilder;

  /// The image grid of an `ImageMessage`, without the caption.
  final MessageWidgetBuilder? imageBuilder;

  /// The poster and play button of a `VideoMessage`.
  final MessageWidgetBuilder? videoBuilder;

  /// The voice note player of an `AudioMessage`.
  final MessageWidgetBuilder? audioBuilder;

  /// The file card (icon, name, size) of a `FileMessage`.
  final MessageWidgetBuilder? fileBuilder;

  /// The centered notice of a `SystemMessage`.
  final MessageWidgetBuilder? systemBuilder;

  /// The "message deleted" placeholder.
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

  /// The author's avatar next to the last message of a group, shown in
  /// groups (and direct rooms with `ChatConfig.showAvatarsInDirect`).
  final MessageWidgetBuilder? avatarBuilder;

  /// The author's (or colleague's) name above the first message of a
  /// group.
  final MessageWidgetBuilder? authorNameBuilder;

  /// The ticks of the current user's messages.
  final MessageWidgetBuilder? statusBuilder;

  /// The message time shown in or under the bubble.
  final MessageWidgetBuilder? timestampBuilder;

  /// The quoted message at the top of a reply.
  final MessageWidgetBuilder? replyPreviewBuilder;

  /// The reaction chips under the bubble.
  final MessageWidgetBuilder? reactionsBuilder;

  /// The day label between messages of different days.
  final DateSeparatorBuilder? dateSeparatorBuilder;

  /// The "new messages" divider above the first unread message.
  final DefaultChildBuilder? unreadDividerBuilder;

  /// The typing indicator at the bottom of the list.
  final TypingIndicatorBuilder? typingBuilder;

  /// The button that scrolls back to the newest message.
  final ScrollToBottomBuilder? scrollToBottomBuilder;

  /// The room with no messages (default: `ChatStrings.noMessages`).
  final DefaultChildBuilder? emptyBuilder;

  /// The spinner shown before the first messages are available.
  final DefaultChildBuilder? loadingBuilder;

  /// An error state for the room. The current room screen does not call
  /// it; read `ChatRoomController.failure` to show errors.
  final ChatErrorBuilder? errorBuilder;

  /// Wraps or replaces the composer at the bottom of `ChatRoomView`.
  final DefaultChildBuilder? composerBuilder;

  /// Replaces or wraps the whole app bar.
  final AppBarBuilder? appBarBuilder;

  /// Adds actions to the default app bar.
  final AppBarActionsBuilder? appBarActions;

  /// Edits the long-press menu of a message; see [MessageAction]. An empty
  /// list (with reactions off) shows no sheet.
  final MessageActionsBuilder? messageActions;
}
