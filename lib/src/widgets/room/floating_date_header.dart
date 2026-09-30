import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/widgets/room/date_separator.dart';

/// The day of the topmost visible message, shown over the list while it
/// scrolls and faded out when it stops.
class FloatingDateHeader extends StatelessWidget {
  const FloatingDateHeader({
    required this.label,
    required this.visible,
    super.key,
  });

  final String? label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible && text != null ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: text == null
            ? const SizedBox.shrink()
            : Center(child: DatePill(label: text)),
      ),
    );
  }
}
