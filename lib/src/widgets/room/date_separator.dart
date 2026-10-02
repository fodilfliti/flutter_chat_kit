import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_styles.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// A centered day label between messages, for example `Today`.
class DateSeparator extends StatelessWidget {
  const DateSeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = ChatTheme.of(context).dateSeparator;
    return Padding(
      padding: style.margin,
      child: Center(
        child: DatePill(label: label, style: style),
      ),
    );
  }
}

/// The rounded label used by [DateSeparator] and the floating date header.
class DatePill extends StatelessWidget {
  const DatePill({required this.label, this.style, super.key});

  final String label;

  /// Defaults to `ChatTheme.dateSeparator`.
  final ChatChipStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatTheme.of(context).dateSeparator;
    return ChatChip(
      style: style,
      child: Text(label, style: style.textStyle),
    );
  }
}

/// A rounded box drawn from a [ChatChipStyle] (color, radius, border and
/// padding; the margin is left to the caller).
class ChatChip extends StatelessWidget {
  const ChatChip({required this.style, required this.child, super.key});

  final ChatChipStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final side = style.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(style.radius),
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
      ),
      child: Padding(padding: style.padding, child: child),
    );
  }
}
