import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// A centered pill for room events ("Ana joined").
class SystemMessageView extends StatelessWidget {
  const SystemMessageView({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.dateSeparatorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: theme.systemMessageStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
