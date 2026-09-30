import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// The rounded card around a message. On the author's side the corners
/// facing the rest of the group, and the bottom one (the tail), use
/// `ChatTheme.tailRadius`.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.child,
    this.color,
    this.padding,
    this.clip = false,
    super.key,
  });

  final MessageContext message;
  final Widget child;

  /// Defaults to the outgoing or incoming bubble color.
  final Color? color;

  /// Defaults to `ChatTheme.bubblePadding`.
  final EdgeInsetsGeometry? padding;

  /// Clips [child] to the shape, for edge-to-edge media.
  final bool clip;

  /// Corners for [position], mirrored for the current user's messages.
  static BorderRadiusDirectional radiusFor(
    GroupPosition position, {
    required bool isMine,
    required ChatTheme theme,
  }) {
    final big = Radius.circular(theme.bubbleRadius);
    final small = Radius.circular(theme.tailRadius);
    final top = position.isFirst ? big : small;
    return isMine
        ? BorderRadiusDirectional.only(
            topStart: big,
            bottomStart: big,
            topEnd: top,
            bottomEnd: small,
          )
        : BorderRadiusDirectional.only(
            topEnd: big,
            bottomEnd: big,
            topStart: top,
            bottomStart: small,
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final mine = message.isMine;
    final radius = radiusFor(message.groupPosition, isMine: mine, theme: theme);
    Widget content = Padding(
      padding: padding ?? theme.bubblePadding,
      child: child,
    );
    if (clip) content = ClipRRect(borderRadius: radius, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            color ??
            (mine ? theme.outgoingBubbleColor : theme.incomingBubbleColor),
        borderRadius: radius,
      ),
      child: content,
    );
  }
}
