import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Three pulsing dots in an incoming bubble, with an optional label such
/// as "Sara is typing".
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({this.label, super.key});

  final String? label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final bubble = theme.incomingBubble;
    final color =
        bubble.textStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final side = bubble.border;
    final label = widget.label;
    return Padding(
      padding: EdgeInsets.only(top: theme.messageList.groupSpacing),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: bubble.color,
              gradient: bubble.gradient,
              borderRadius: BorderRadius.circular(bubble.radius),
              border: side == BorderSide.none
                  ? null
                  : Border.fromBorderSide(side),
              boxShadow: bubble.shadows.isEmpty ? null : bubble.shadows,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12) *
                  theme.scale,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) _dot(i, color, theme.scale),
                  ],
                ),
              ),
            ),
          ),
          if (label != null && label.isNotEmpty)
            Flexible(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: theme.size(8)),
                child: Text(
                  label,
                  style: bubble.metaStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(int i, Color color, double scale) {
    final phase = (_pulse.value - i * 0.2) % 1;
    final t = math.sin(phase * math.pi).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2 * scale),
      child: Opacity(
        opacity: 0.35 + 0.65 * t,
        child: SizedBox.square(
          dimension: 7 * scale,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
