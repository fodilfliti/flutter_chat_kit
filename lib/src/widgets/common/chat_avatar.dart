import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// A round avatar: the image at [url] over the initials of [name].
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({required this.name, this.url, this.size, super.key});

  final String name;
  final String? url;

  /// Diameter; defaults to `ChatTheme.avatarSize`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final diameter = size ?? theme.avatarSize;
    final image = url;
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: theme.avatarBackgroundColor,
      foregroundImage: image == null || image.isEmpty
          ? null
          : CachedNetworkImageProvider(image, errorListener: _ignore),
      onForegroundImageError: image == null || image.isEmpty ? null : (_, _) {},
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: diameter * 0.4,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
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
