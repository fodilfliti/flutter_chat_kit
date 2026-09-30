import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/widgets/common/chat_avatar.dart';

/// The name to show for [room]: its title, else the peer's name for a
/// direct room, else the resolved names of the other members.
String roomDisplayName(
  ChatRoom room,
  String currentUserId,
  Map<String, ChatUser> users,
) {
  final title = room.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  if (room.isDirect) {
    final peer = room.otherUserId(currentUserId);
    return peer == null ? '' : users[peer]?.name ?? '';
  }
  return [
    for (final member in room.members)
      if (member.userId != currentUserId) ?users[member.userId]?.name,
  ].join(', ');
}

/// Avatar of a room: the peer for a direct room, the room image for a
/// group, or two stacked member avatars for a group without one. Shows an
/// online dot when [online].
class RoomAvatar extends StatelessWidget {
  const RoomAvatar({
    required this.room,
    required this.currentUserId,
    this.users = const {},
    this.size = 48,
    this.online = false,
    this.onlineColor = const Color(0xFF34C759),
    super.key,
  });

  final ChatRoom room;
  final String currentUserId;

  /// Resolved users, for peer and member avatars.
  final Map<String, ChatUser> users;
  final double size;
  final bool online;
  final Color onlineColor;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final name = roomDisplayName(room, currentUserId, users);
    final Widget avatar;
    if (room.isDirect) {
      final peerId = room.otherUserId(currentUserId);
      final peer = peerId == null ? null : users[peerId];
      avatar = ChatAvatar(
        name: name,
        url: peer?.avatarUrl ?? room.avatarUrl,
        size: size,
      );
    } else if (room.avatarUrl case final url? when url.isNotEmpty) {
      avatar = ChatAvatar(name: name, url: url, size: size);
    } else {
      avatar = _stacked(name, surface);
    }
    if (!online) return avatar;
    final dot = size * 0.28;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          avatar,
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                border: Border.all(color: surface, width: dot * 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stacked(String name, Color ring) {
    final others = [
      for (final member in room.members)
        if (member.userId != currentUserId) ?users[member.userId],
    ];
    if (others.length < 2) {
      final only = others.firstOrNull;
      return ChatAvatar(
        name: only?.name ?? name,
        url: only?.avatarUrl,
        size: size,
      );
    }
    final inner = size * 0.68;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            child: ChatAvatar(
              name: others[0].name,
              url: others[0].avatarUrl,
              size: inner,
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 2),
              ),
              child: ChatAvatar(
                name: others[1].name,
                url: others[1].avatarUrl,
                size: inner - 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
