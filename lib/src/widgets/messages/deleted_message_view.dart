import 'package:flutter/material.dart';

/// Placeholder for a deleted message.
class DeletedMessageView extends StatelessWidget {
  const DeletedMessageView({
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
        Icon(Icons.block, size: (style.fontSize ?? 14) + 2, color: style.color),
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
