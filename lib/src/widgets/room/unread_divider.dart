import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// "New messages" line above the first message that was unread when the
/// room opened, drawn from `ChatTheme.unreadDivider`.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = ChatTheme.of(context).unreadDivider;
    final line = Expanded(child: Divider(color: style.color));
    return Padding(
      padding: style.margin,
      child: Row(
        children: [
          line,
          Padding(
            padding: style.padding,
            child: Text(label, style: style.textStyle),
          ),
          line,
        ],
      ),
    );
  }
}
