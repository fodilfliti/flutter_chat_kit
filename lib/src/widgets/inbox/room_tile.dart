import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/inbox_builders.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/widgets/common/message_snippet.dart';
import 'package:flutter_chat_kit/src/widgets/common/room_avatar.dart';

/// One inbox row: avatar with online dot, name, muted icon, last message
/// preview (or who is typing), time, pinned icon and unread badge.
///
/// Each part goes through the matching [InboxBuilders] hook.
class RoomTile extends StatelessWidget {
  const RoomTile({
    required this.room,
    this.users = const {},
    this.onTap,
    this.onLongPress,
    this.builders = const InboxBuilders(),
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.avatarSize = 52,
    super.key,
  });

  final RoomContext room;

  /// Resolved users, for group names and avatars.
  final Map<String, ChatUser> users;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final InboxBuilders builders;
  final ChatStrings strings;
  final ChatFormatters formatters;
  final double avatarSize;

  /// The preview line of [room]'s last message, prefixed with its author
  /// ("You", a group member, or the colleague who answered for a business
  /// profile).
  static String previewOf(
    RoomContext room,
    ChatStrings strings, {
    ChatFormatters formatters = const ChatFormatters(),
  }) {
    final last = room.room.lastMessage;
    if (last == null) return '';
    var text = messageSnippet(last, strings);
    if (last is AudioMessage && !last.isDeleted) {
      if (last.audio.duration case final duration?) {
        text = formatters.formatDuration(duration);
      }
    }
    if (last is SystemMessage || last.isDeleted) return text;
    if (room.lastMessageIsMine) {
      final colleague = room.lastMessageSentByColleague
          ? room.lastMessageSender?.name
          : null;
      return strings.previewWithAuthor(
        colleague == null || colleague.isEmpty ? strings.you : colleague,
        text,
      );
    }
    final author = room.lastMessageAuthor?.name;
    if (!room.room.isDirect && author != null && author.isNotEmpty) {
      return strings.previewWithAuthor(author, text);
    }
    return text;
  }

  static IconData? _kindIcon(Message message) {
    if (message.isDeleted) return Icons.block;
    return switch (message) {
      ImageMessage() => Icons.photo_outlined,
      VideoMessage() => Icons.videocam_outlined,
      AudioMessage() => Icons.mic_none,
      FileMessage() => Icons.attach_file,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = room.room;
    final unread = room.hasUnread;
    final highlight = unread && !r.muted;

    Widget leading = RoomAvatar(
      room: r,
      currentUserId: room.currentUserId,
      users: users,
      size: avatarSize,
      online: room.presence?.isOnline ?? false,
    );
    if (builders.leadingBuilder case final build?) {
      leading = build(context, room, leading);
    }

    Widget title = Row(
      children: [
        Flexible(
          child: Text(
            roomDisplayName(r, room.currentUserId, users),
            style: theme.roomTitleStyle.copyWith(
              fontWeight: unread ? FontWeight.w700 : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (r.muted)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Icon(
              Icons.volume_off,
              size: 16,
              color: theme.iconColor,
              semanticLabel: strings.mute,
            ),
          ),
      ],
    );
    if (builders.titleBuilder case final build?) {
      title = build(context, room, title);
    }

    Widget subtitle;
    if (room.isTyping) {
      subtitle = Text(
        strings.typing(room.typingNames),
        style: theme.roomSubtitleStyle.copyWith(color: scheme.primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      final last = r.lastMessage;
      final icon = last == null ? null : _kindIcon(last);
      subtitle = Row(
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Icon(icon, size: 16, color: theme.iconColor),
            ),
          Expanded(
            child: Text(
              previewOf(room, strings, formatters: formatters),
              style: theme.roomSubtitleStyle.copyWith(
                color: unread ? scheme.onSurface : null,
                fontStyle: last?.isDeleted ?? false ? FontStyle.italic : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (builders.subtitleBuilder case final build?) {
      subtitle = build(context, room, subtitle);
    }

    final time = r.lastMessage?.createdAt ?? r.updatedAt;
    Widget trailing = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatters.formatRoomTime(time, strings),
          style: theme.roomTimeStyle.copyWith(
            color: highlight ? theme.unreadBadgeColor : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.pinned)
              Icon(
                Icons.push_pin,
                size: 16,
                color: theme.iconColor,
                semanticLabel: strings.pin,
              ),
            if (r.pinned && unread) const SizedBox(width: 4),
            if (unread)
              _UnreadBadge(
                count: r.unreadCount,
                muted: r.muted,
                strings: strings,
              ),
            if (!r.pinned && !unread) const SizedBox(height: 20),
          ],
        ),
      ],
    );
    if (builders.trailingBuilder case final build?) {
      trailing = build(context, room, trailing);
    }

    Widget tile = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), subtitle],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
    if (builders.tileBuilder case final build?) {
      tile = build(context, room, tile);
    }
    return tile;
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.muted,
    required this.strings,
  });

  final int count;
  final bool muted;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return Semantics(
      label: strings.unreadCount(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? theme.iconColor : theme.unreadBadgeColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: theme.unreadBadgeTextStyle,
        ),
      ),
    );
  }
}
