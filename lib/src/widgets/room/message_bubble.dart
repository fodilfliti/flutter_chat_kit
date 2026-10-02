import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/builders/message_context.dart';
import 'package:flutter_chat_pro/src/config/chat_styles.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// The rounded card around a message, drawn from the side's
/// [ChatBubbleStyle] (color or gradient, border, shadows). On the author's
/// side the corners facing the rest of the group, and the bottom one (the
/// tail), use `ChatBubbleStyle.tailRadius`.
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

  /// Defaults to the side's `ChatBubbleStyle.color`.
  final Color? color;

  /// Defaults to the side's `ChatBubbleStyle.padding`.
  final EdgeInsetsGeometry? padding;

  /// Clips [child] to the shape, for edge-to-edge media.
  final bool clip;

  /// Corners for [position], mirrored for the current user's messages.
  static BorderRadiusDirectional radiusFor(
    GroupPosition position, {
    required bool isMine,
    required ChatTheme theme,
  }) {
    final style = theme.bubble(isMine: isMine);
    final big = Radius.circular(style.radius);
    final small = Radius.circular(style.tailRadius);
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
    final style = theme.bubble(isMine: mine);
    final radius = radiusFor(message.groupPosition, isMine: mine, theme: theme);
    Widget content = Padding(padding: padding ?? style.padding, child: child);
    if (clip) content = ClipRRect(borderRadius: radius, child: content);
    final side = style.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? style.color,
        gradient: color == null ? style.gradient : null,
        borderRadius: radius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: style.shadows.isEmpty ? null : style.shadows,
      ),
      child: side == BorderSide.none
          ? content
          : Padding(padding: EdgeInsets.all(side.width), child: content),
    );
  }
}
