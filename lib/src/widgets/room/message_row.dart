import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/builders/message_context.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/models/message.dart';

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

  /// Drawn above the first message of a group: the author in groups, or the
  /// colleague who answered for a shared business profile.
  final Widget? authorName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final style = theme.messageList;
    final position = message.groupPosition;
    final top = position.isFirst ? style.groupSpacing : style.messageSpacing;
    final background = message.isHighlighted
        ? style.highlightColor
        : message.isSelected
        ? style.selectedColor
        : style.highlightColor.withValues(alpha: 0);

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
              padding: mine
                  ? _mirror(style.authorNamePadding)
                  : style.authorNamePadding,
              child: name,
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: content,
          ),
        ],
      );
      final selecting = message.isSelectionMode;
      body = Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (selecting)
            Padding(
              padding: EdgeInsetsDirectional.only(
                end: theme.size(8),
                bottom: theme.size(4),
              ),
              child: Icon(
                message.isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: style.selectionIconSize,
                color: message.isSelected
                    ? style.selectionColor
                    : theme.iconColor,
              ),
            ),
          if (showAvatar && !mine)
            Padding(
              padding: EdgeInsetsDirectional.only(end: style.avatarGap),
              child: SizedBox(
                width: style.avatarSize,
                child: position.isLast ? avatar : null,
              ),
            ),
          if (selecting)
            Expanded(
              child: Align(
                alignment: mine
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                heightFactor: 1,
                child: column,
              ),
            )
          else
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

  static EdgeInsetsDirectional _mirror(EdgeInsetsDirectional p) =>
      EdgeInsetsDirectional.fromSTEB(p.end, p.top, p.start, p.bottom);
}
