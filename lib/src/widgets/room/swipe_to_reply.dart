import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// Drag a message towards the reading end (right in left-to-right) past
/// [threshold] to reply; it springs back when released.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    required this.child,
    required this.onReply,
    this.enabled = true,
    this.threshold = 64,
    super.key,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final double threshold;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController(
    vsync: this,
    upperBound: widget.threshold * 1.5,
    duration: const Duration(milliseconds: 180),
  );
  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double get _direction =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _onUpdate(DragUpdateDetails details) {
    final delta = (details.primaryDelta ?? 0) * _direction;
    _offset.value = (_offset.value + delta).clamp(0, _offset.upperBound);
    final armed = _offset.value >= widget.threshold;
    if (armed && !_armed) HapticFeedback.selectionClick().ignore();
    _armed = armed;
  }

  void _onEnd([DragEndDetails? _]) {
    if (_armed) widget.onReply();
    _armed = false;
    _offset.animateBack(0, curve: Curves.easeOutCubic).ignore();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final theme = ChatTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onEnd,
      child: AnimatedBuilder(
        animation: _offset,
        child: widget.child,
        builder: (context, child) {
          final progress = (_offset.value / widget.threshold).clamp(0.0, 1.0);
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              if (progress > 0)
                PositionedDirectional(
                  start: theme.size(8),
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * progress,
                      child: Icon(
                        Icons.reply,
                        color: theme.iconColor,
                        size: theme.size(24),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_offset.value * _direction, 0),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}
