import 'package:flutter/material.dart';

/// Shown for a `CustomMessage` type without a builder.
class UnsupportedMessageView extends StatelessWidget {
  const UnsupportedMessageView({
    required this.label,
    required this.style,
    super.key,
  });

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.help_outline,
          size: (style.fontSize ?? 14) + 2,
          color: style.color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}
