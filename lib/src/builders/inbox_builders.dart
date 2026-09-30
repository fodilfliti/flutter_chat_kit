import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';

/// Everything an inbox row builder needs.
@immutable
class RoomContext {
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

  final ChatRoom room;
  final String currentUserId;
  final int index;

  /// `ChatKit.agentId`: the staff member using a shared business profile.
  final String? agentId;

  /// The other member of a direct room, once resolved.
  final ChatUser? peer;
  final ChatUser? lastMessageAuthor;

  /// The staff member who sent the last message (`Message.sentBy`), once
  /// resolved.
  final ChatUser? lastMessageSender;

  /// Presence of [peer], when the source reports it.
  final Presence? presence;

  /// Names of members typing in this room right now.
  final List<String> typingNames;

  bool get isTyping => typingNames.isNotEmpty;

  bool get hasUnread => room.unreadCount > 0;

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

/// A swipe action on an inbox row.
@immutable
class RoomAction {
  const RoomAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTap;
  final bool isDestructive;
}

/// Customization hooks for the inbox.
@immutable
class InboxBuilders {
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
  final RoomWidgetBuilder? leadingBuilder;
  final RoomWidgetBuilder? titleBuilder;

  /// Last message preview or typing line.
  final RoomWidgetBuilder? subtitleBuilder;

  /// Time and unread badge.
  final RoomWidgetBuilder? trailingBuilder;
  final DefaultChildBuilder? emptyBuilder;
  final DefaultChildBuilder? loadingBuilder;
  final ChatErrorBuilder? errorBuilder;
  final DefaultChildBuilder? searchBarBuilder;
  final RoomActionsBuilder? swipeActions;
}
