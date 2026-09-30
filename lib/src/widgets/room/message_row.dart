import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/message.dart';

/// Lays out one message: the avatar column, the author name and the
/// [content] (usually a bubble), aligned to the author's side, with group
/// spacing and the highlight / selection background. It draws no content
/// itself.
class MessageRow extends StatelessWidget {
  const MessageRow({
    required this.message,
    required this.content,
    required this.maxContentWidth,
    this.showAvatar = false,
    this.avatar,
    this.authorName,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final MessageContext message;
  final Widget content;
  final double maxContentWidth;

  /// Reserves the avatar column for incoming messages.
  final bool showAvatar;

  /// Drawn next to the last (newest) message of a group.
  final Widget? avatar;

  /// Drawn above the first message of a group.
  final Widget? authorName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final position = message.groupPosition;
    final top = position.isFirst ? theme.groupSpacing : theme.messageSpacing;
    final background = message.isHighlighted
        ? theme.highlightColor
        : message.isSelected
        ? theme.selectedColor
        : theme.highlightColor.withValues(alpha: 0);

    final Widget body;
    if (message.message is SystemMessage) {
      body = Center(child: content);
    } else {
      final mine = message.isMine;
      final name = authorName;
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (name != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: name,
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: content,
          ),
        ],
      );
      body = Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar && !mine)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: theme.avatarSize,
                child: position.isLast ? avatar : null,
              ),
            ),
          Flexible(child: column),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: background,
        padding: EdgeInsets.only(top: top),
        child: body,
      ),
    );
  }
}
