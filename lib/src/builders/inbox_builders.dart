import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';

/// Everything an inbox row builder needs.
@immutable
class RoomContext {
  /// Built by `InboxView` for each row.
  const RoomContext({
    required this.room,
    required this.currentUserId,
    required this.index,
    this.agentId,
    this.peer,
    this.lastMessageAuthor,
    this.lastMessageSender,
    this.presence,
    this.typingNames = const [],
  });

  /// The room of this row.
  final ChatRoom room;

  /// `ChatKit.currentUserId`.
  final String currentUserId;

  /// Position of the row in the list (0 = top).
  final int index;

  /// `ChatKit.agentId`: the staff member using a shared business profile.
  final String? agentId;

  /// The other member of a direct room, once resolved.
  final ChatUser? peer;

  /// Author of `room.lastMessage`, once resolved; usually null for the
  /// current user's own messages, which are not resolved.
  final ChatUser? lastMessageAuthor;

  /// The staff member who sent the last message (`Message.sentBy`), once
  /// resolved.
  final ChatUser? lastMessageSender;

  /// Presence of [peer], when the source reports it.
  final Presence? presence;

  /// Names of members typing in this room right now.
  final List<String> typingNames;

  /// Whether someone is typing; the subtitle then shows the typing line
  /// instead of the last message.
  bool get isTyping => typingNames.isNotEmpty;

  /// Whether the room has unread messages; the tile then uses the unread
  /// text styles and shows a badge.
  bool get hasUnread => room.unreadCount > 0;

  /// Whether the last message was sent as the current profile.
  bool get lastMessageIsMine => room.lastMessage?.authorId == currentUserId;

  /// The last message was sent for this profile by another staff member.
  bool get lastMessageSentByColleague {
    final sentBy = room.lastMessage?.sentBy;
    return lastMessageIsMine && sentBy != null && sentBy != agentId;
  }
}

/// Wraps or replaces part of an inbox row.
typedef RoomWidgetBuilder =
    Widget Function(
      BuildContext context,
      RoomContext room,
      Widget defaultChild,
    );

/// Edits the swipe actions of a row; return [defaults] to keep them.
typedef RoomActionsBuilder =
    List<RoomAction> Function(
      BuildContext context,
      RoomContext room,
      List<RoomAction> defaults,
    );

/// A swipe action on an inbox row, also listed in the long-press sheet.
/// The defaults have the ids `'pin'` and `'mute'`.
///
/// ```dart
/// swipeActions: (context, room, defaults) => [
///   ...defaults,
///   RoomAction(
///     id: 'archive',
///     label: 'Archive',
///     icon: Icons.archive_outlined,
///     onTap: () => archive(room.room.id),
///   ),
/// ],
/// ```
@immutable
class RoomAction {
  /// An action labeled [label] with [icon] that runs [onTap].
  const RoomAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  /// Stable id, for finding or removing an action in a builder.
  final String id;

  /// Text under the icon (swipe) or next to it (sheet).
  final String label;

  /// Icon of the action.
  final IconData icon;

  /// Runs when the action is tapped.
  final FutureOr<void> Function() onTap;

  /// Draws the action in the theme's error colors, as for delete. Defaults
  /// to false.
  final bool isDestructive;
}

/// Customization hooks for the inbox. Each builder receives the default
/// widget so it can wrap it instead of rebuilding it; null keeps the
/// default. Pass it as `InboxView.builders`. See doc/customization.md.
@immutable
class InboxBuilders {
  /// Hooks for the inbox; all null by default.
  const InboxBuilders({
    this.tileBuilder,
    this.leadingBuilder,
    this.titleBuilder,
    this.subtitleBuilder,
    this.trailingBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.searchBarBuilder,
    this.swipeActions,
  });

  /// The whole row.
  final RoomWidgetBuilder? tileBuilder;

  /// The room avatar, with the online dot for direct rooms.
  final RoomWidgetBuilder? leadingBuilder;

  /// The room name, with the muted icon.
  final RoomWidgetBuilder? titleBuilder;

  /// Last message preview or typing line.
  final RoomWidgetBuilder? subtitleBuilder;

  /// Time and unread badge.
  final RoomWidgetBuilder? trailingBuilder;

  /// The list with no rooms: `ChatStrings.noChats`, or
  /// `ChatStrings.noResults` while searching.
  final DefaultChildBuilder? emptyBuilder;

  /// The spinner shown while the list is empty and rooms are loading.
  final DefaultChildBuilder? loadingBuilder;

  /// Shown when the list is empty and the last load failed; `retry` calls
  /// `InboxController.refresh`.
  final ChatErrorBuilder? errorBuilder;

  /// The search bar above the list (when `InboxView.showSearch` is true).
  final DefaultChildBuilder? searchBarBuilder;

  /// Edits the pin and mute actions of each row; see [RoomAction]. An
  /// empty list disables swiping and the long-press sheet.
  final RoomActionsBuilder? swipeActions;
}
