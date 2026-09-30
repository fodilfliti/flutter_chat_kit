import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// "New messages" line above the first message that was unread when the
/// room opened.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final line = Expanded(
      child: Divider(color: theme.unreadBadgeColor.withValues(alpha: 0.4)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.dateSeparatorStyle.copyWith(
                color: theme.unreadBadgeColor,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
