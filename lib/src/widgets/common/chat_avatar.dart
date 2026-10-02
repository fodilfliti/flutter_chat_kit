import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// An avatar: the image at [url] over the initials of [name], round or
/// rounded per `ChatAvatarStyle.radius`.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({required this.name, this.url, this.size, super.key});

  final String name;
  final String? url;

  /// Diameter; defaults to `ChatMessageListStyle.avatarSize`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final style = theme.avatar;
    final diameter = size ?? theme.messageList.avatarSize;
    final image = url;
    final radius = BorderRadius.circular(style.radius ?? diameter / 2);
    final side = style.border;
    return Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: side == BorderSide.none
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.fromBorderSide(side),
            ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: radius,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              initialsOf(name),
              style: TextStyle(
                fontSize: diameter * 0.4,
                fontWeight: FontWeight.w600,
                color: style.foregroundColor,
              ),
            ),
          ),
          if (image != null && image.isNotEmpty)
            Image(
              image: CachedNetworkImageProvider(image, errorListener: _ignore),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  /// Failed loads (offline, 404) fall back to the initials.
  static void _ignore(Object _) {}

  /// Up to two initials: first letters of the first and last words.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }
}
