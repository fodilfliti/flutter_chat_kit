import 'package:flutter/widgets.dart';

/// The trailing line of a bubble: "edited", the time and the status ticks.
class MessageMeta extends StatelessWidget {
  const MessageMeta({required this.time, this.edited, this.ticks, super.key});

  final Widget time;
  final Widget? edited;
  final Widget? ticks;

  @override
  Widget build(BuildContext context) {
    final edited = this.edited;
    final ticks = this.ticks;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (edited != null) ...[edited, const SizedBox(width: 4)],
        time,
        if (ticks != null) ...[const SizedBox(width: 3), ticks],
      ],
    );
  }
}
