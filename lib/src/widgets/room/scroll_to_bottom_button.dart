import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// Round button that returns the list to the newest message, with a badge
/// counting messages that arrived while scrolled up.
class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({
    required this.unreadCount,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final int unreadCount;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final badge = theme.badge;
    return Badge(
      isLabelVisible: unreadCount > 0,
      backgroundColor: badge.color,
      largeSize: badge.size,
      padding: badge.padding,
      label: Text('$unreadCount', style: badge.textStyle),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: theme.size(24),
          icon: Icon(Icons.keyboard_arrow_down, color: theme.iconColor),
        ),
      ),
    );
  }
}
