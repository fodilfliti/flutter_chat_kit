import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// The trailing line of a bubble: "edited", the time and the status ticks.
class MessageMeta extends StatelessWidget {
  const MessageMeta({required this.time, this.edited, this.ticks, super.key});

  final Widget time;
  final Widget? edited;
  final Widget? ticks;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final edited = this.edited;
    final ticks = this.ticks;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (edited != null) ...[edited, SizedBox(width: theme.size(4))],
        time,
        if (ticks != null) ...[SizedBox(width: theme.size(3)), ticks],
      ],
    );
  }
}
