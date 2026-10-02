import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/builders/inbox_builders.dart';
import 'package:flutter_chat_pro/src/config/chat_formatters.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_styles.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/widgets/common/message_snippet.dart';
import 'package:flutter_chat_pro/src/widgets/common/room_avatar.dart';

/// One inbox row: avatar with online dot, name, muted icon, last message
/// preview (or who is typing), time, pinned icon and unread badge.
///
/// Drawn from `ChatTheme.roomTile` (plain, divided or card, any shape);
/// each part goes through the matching [InboxBuilders] hook.
class RoomTile extends StatelessWidget {
  const RoomTile({
    required this.room,
    this.users = const {},
    this.onTap,
    this.onLongPress,
    this.builders = const InboxBuilders(),
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.avatarSize,
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

  /// Defaults to `ChatRoomTileStyle.avatarSize`.
  final double? avatarSize;

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
    final style = theme.roomTile;
    final avatarSize = this.avatarSize ?? style.avatarSize;
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
            style: unread ? style.unreadTitleStyle : style.titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (r.muted)
          Padding(
            padding: EdgeInsetsDirectional.only(start: theme.size(4)),
            child: Icon(
              Icons.volume_off,
              size: style.iconSize,
              color: style.iconColor,
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
        style: style.typingStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      final last = r.lastMessage;
      final icon = last == null ? null : _kindIcon(last);
      final preview = unread ? style.unreadSubtitleStyle : style.subtitleStyle;
      subtitle = Row(
        children: [
          if (icon != null)
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.size(4)),
              child: Icon(icon, size: style.iconSize, color: style.iconColor),
            ),
          Expanded(
            child: Text(
              previewOf(room, strings, formatters: formatters),
              style: last?.isDeleted ?? false
                  ? preview.copyWith(fontStyle: FontStyle.italic)
                  : preview,
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
          formatters.formatRoomTime(
            time,
            strings,
            locale: Localizations.maybeLocaleOf(context)?.toString(),
          ),
          style: highlight ? style.unreadTimeStyle : style.timeStyle,
        ),
        SizedBox(height: theme.size(6)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.pinned)
              Icon(
                Icons.push_pin,
                size: style.iconSize,
                color: style.iconColor,
                semanticLabel: strings.pin,
              ),
            if (r.pinned && unread) SizedBox(width: theme.size(4)),
            if (unread)
              ChatUnreadBadge(
                count: r.unreadCount,
                muted: r.muted,
                semanticLabel: strings.unreadCount(r.unreadCount),
              ),
            if (!r.pinned && !unread) SizedBox(height: theme.badge.size),
          ],
        ),
      ],
    );
    if (builders.trailingBuilder case final build?) {
      trailing = build(context, room, trailing);
    }

    final content = Padding(
      padding: style.padding,
      child: Row(
        children: [
          leading,
          SizedBox(width: style.gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                SizedBox(height: style.lineGap),
                subtitle,
              ],
            ),
          ),
          SizedBox(width: style.trailingGap),
          trailing,
        ],
      ),
    );
    var tile = _frame(
      style,
      content,
      indent: style.padding.left + avatarSize + style.gap,
    );
    if (builders.tileBuilder case final build?) {
      tile = build(context, room, tile);
    }
    return tile;
  }

  /// Background, shape, elevation, divider and margin around [content].
  Widget _frame(
    ChatRoomTileStyle style,
    Widget content, {
    required double indent,
  }) {
    final plain =
        style.color == null &&
        style.elevation == 0 &&
        style.shape == const RoundedRectangleBorder();
    Widget tile = Material(
      type: plain ? MaterialType.transparency : MaterialType.canvas,
      color: style.color ?? Colors.transparent,
      shape: style.shape,
      elevation: style.elevation,
      clipBehavior: plain ? Clip.none : Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: style.shape,
        child: content,
      ),
    );
    final divider = style.divider;
    if (divider != BorderSide.none) {
      tile = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile,
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: style.dividerIndent ?? indent,
            ),
            child: ColoredBox(
              color: divider.color,
              child: SizedBox(height: divider.width),
            ),
          ),
        ],
      );
    }
    if (style.margin != EdgeInsets.zero) {
      tile = Padding(padding: style.margin, child: tile);
    }
    return tile;
  }
}

/// An unread counter drawn from `ChatTheme.badge`; shows "99+" above 99.
class ChatUnreadBadge extends StatelessWidget {
  const ChatUnreadBadge({
    required this.count,
    this.muted = false,
    this.semanticLabel,
    super.key,
  });

  final int count;

  /// Uses `ChatBadgeStyle.mutedColor`.
  final bool muted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = ChatTheme.of(context).badge;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        constraints: BoxConstraints(minWidth: style.size),
        height: style.size,
        padding: style.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? style.mutedColor : style.color,
          borderRadius: BorderRadius.circular(style.radius),
        ),
        child: Text(count > 99 ? '99+' : '$count', style: style.textStyle),
      ),
    );
  }
}
