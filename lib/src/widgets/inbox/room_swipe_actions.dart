import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_chat_kit/src/builders/inbox_builders.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Reveals [actions] at the trailing edge when [child] is swiped towards
/// the leading edge. Tapping an action runs it and closes the row.
///
/// The actions are also exposed as accessibility actions.
class RoomSwipeActions extends StatefulWidget {
  const RoomSwipeActions({
    required this.actions,
    required this.child,
    this.actionWidth,
    super.key,
  });

  final List<RoomAction> actions;
  final Widget child;

  /// Defaults to 76 at the theme scale.
  final double? actionWidth;

  @override
  State<RoomSwipeActions> createState() => _RoomSwipeActionsState();
}

class _RoomSwipeActionsState extends State<RoomSwipeActions>
    with SingleTickerProviderStateMixin {
  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double get _actionWidth =>
      widget.actionWidth ?? ChatTheme.of(context).size(76);

  double get _extent => widget.actions.length * _actionWidth;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _open.value -= (rtl ? -delta : delta) / _extent;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final towardsOpen = rtl ? velocity > 0 : velocity < 0;
    if (velocity.abs() > 700) {
      unawaited(towardsOpen ? _open.forward() : _open.reverse());
    } else {
      unawaited(_open.value > 0.5 ? _open.forward() : _open.reverse());
    }
  }

  Future<void> _run(RoomAction action) async {
    _open.reverse();
    await action.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = ChatTheme.of(context);
    if (widget.actions.isEmpty) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      customSemanticsActions: {
        for (final action in widget.actions)
          CustomSemanticsAction(label: action.label): () =>
              unawaited(_run(action)),
      },
      child: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in widget.actions)
                        SizedBox(
                          width: _actionWidth,
                          child: Material(
                            color: action.isDestructive
                                ? scheme.error
                                : scheme.secondaryContainer,
                            child: InkWell(
                              onTap: () => unawaited(_run(action)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    action.icon,
                                    size: chat.size(24),
                                    color: action.isDestructive
                                        ? scheme.onError
                                        : scheme.onSecondaryContainer,
                                  ),
                                  SizedBox(height: chat.size(4)),
                                  Text(
                                    action.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: chat.roomTile.timeStyle.copyWith(
                                      color: action.isDestructive
                                          ? scheme.onError
                                          : scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _open,
              builder: (context, child) => Transform.translate(
                offset: Offset((rtl ? 1 : -1) * _open.value * _extent, 0),
                child: child,
              ),
              child: Material(
                color: theme.scaffoldBackgroundColor,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
