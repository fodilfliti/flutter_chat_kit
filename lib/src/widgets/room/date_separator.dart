import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// A centered day label between messages, for example `Today`.
class DateSeparator extends StatelessWidget {
  const DateSeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DatePill(label: label, theme: theme),
      ),
    );
  }
}

/// The rounded label used by [DateSeparator] and the floating date header.
class DatePill extends StatelessWidget {
  const DatePill({required this.label, required this.theme, super.key});

  final String label;
  final ChatTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.dateSeparatorColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(label, style: theme.dateSeparatorStyle),
      ),
    );
  }
}
