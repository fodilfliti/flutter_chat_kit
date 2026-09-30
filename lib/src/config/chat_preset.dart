import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_styles.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Builds the base theme of a preset from the chat's colors and fonts.
typedef ChatThemeFactory =
    ChatTheme Function(ColorScheme scheme, TextTheme textTheme);

/// Layout of the inbox rows.
enum ChatTiles {
  /// Edge to edge rows without lines.
  plain,

  /// A thin line under each row.
  divided,

  /// Separate rounded cards; the corner radius is `ChatStyle.tileRadius`.
  cards,
}

/// A ready-made look for `ChatStyle(preset: ...)`.
///
/// [build] makes the base theme (colors, gradients, wallpaper); the other
/// fields are the preset's defaults for the simple `ChatStyle` options,
/// which the same options on `ChatStyle` override. Make your own:
///
/// ```dart
/// const brand = ChatPreset(
///   name: 'Brand',
///   seedColor: Color(0xFF6750A4),
///   bubbleRadius: 12,
///   tiles: ChatTiles.cards,
/// );
/// ```
@immutable
class ChatPreset {
  const ChatPreset({
    required this.name,
    this.seedColor,
    this.build = _fallback,
    this.bubbleRadius,
    this.bubbleShadows,
    this.bubbleBorder,
    this.messageStyle,
    this.tiles,
    this.tileRadius,
    this.squareAvatars,
  });

  /// Shown in pickers.
  final String name;

  /// Chat colors come from this seed; null keeps the app's colors.
  final Color? seedColor;
  final ChatThemeFactory build;
  final double? bubbleRadius;
  final bool? bubbleShadows;
  final bool? bubbleBorder;

  /// Merged into the message text of both bubbles.
  final TextStyle? messageStyle;
  final ChatTiles? tiles;
  final double? tileRadius;
  final bool? squareAvatars;

  static ChatTheme _fallback(ColorScheme scheme, TextTheme text) =>
      ChatTheme.fallback(scheme, textTheme: text);

  /// The default look, in the app's colors.
  static const classic = ChatPreset(name: 'Classic');

  /// Green and white bubbles with flat tails, a wallpaper, blue seen ticks
  /// and lined rows.
  static const whatsApp = ChatPreset(
    name: 'WhatsApp-like',
    seedColor: Color(0xFF25D366),
    build: _whatsApp,
    messageStyle: TextStyle(fontSize: 15),
    bubbleRadius: 8,
    bubbleShadows: true,
    tiles: ChatTiles.divided,
  );

  /// Gradient outgoing bubbles over a gradient background.
  static const telegram = ChatPreset(
    name: 'Telegram-like',
    seedColor: Color(0xFF2AABEE),
    build: _telegram,
    bubbleRadius: 16,
  );

  /// Flat bordered bubbles, grey text, square avatars and lined rows, in
  /// the app's colors.
  static const minimal = ChatPreset(
    name: 'Minimal',
    build: _minimal,
    messageStyle: TextStyle(fontSize: 14),
    bubbleRadius: 6,
    bubbleBorder: true,
    tiles: ChatTiles.divided,
    squareAvatars: true,
  );

  /// Round bubbles with shadows and card rows, in the app's colors.
  static const cards = ChatPreset(
    name: 'Cards',
    build: _cards,
    bubbleRadius: 22,
    bubbleShadows: true,
    tiles: ChatTiles.cards,
    tileRadius: 20,
  );

  static const List<ChatPreset> values = [
    classic,
    whatsApp,
    telegram,
    minimal,
    cards,
  ];

  static ChatTheme _whatsApp(ColorScheme scheme, TextTheme text) {
    final dark = scheme.brightness == Brightness.dark;
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final ink = dark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final meta = dark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    ChatBubbleStyle bubble(ChatBubbleStyle b, Color color) => b.copyWith(
      color: color,
      textStyle: b.textStyle.copyWith(color: ink),
      metaStyle: b.metaStyle.copyWith(color: meta),
      accentColor: const Color(0xFF06CF9C),
      tailRadius: 0,
    );
    return chat.copyWith(
      outgoingBubble: bubble(
        chat.outgoingBubble,
        dark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3),
      ),
      incomingBubble: bubble(
        chat.incomingBubble,
        dark ? const Color(0xFF202C33) : Colors.white,
      ),
      status: chat.status.copyWith(seenColor: const Color(0xFF53BDEB)),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(
          color: dark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
        ),
      ),
    );
  }

  static ChatTheme _telegram(ColorScheme scheme, TextTheme text) {
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final dark = scheme.brightness == Brightness.dark;
    return chat.copyWith(
      outgoingBubble: chat.outgoingBubble.copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF2AABEE), Color(0xFF6A5AE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        textStyle: chat.outgoingBubble.textStyle.copyWith(color: Colors.white),
        metaStyle: chat.outgoingBubble.metaStyle.copyWith(
          color: Colors.white70,
        ),
        accentColor: Colors.white,
      ),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF17212B), Color(0xFF0E1621)]
                : const [Color(0xFFD7E8C9), Color(0xFFA9D18E)],
          ),
        ),
      ),
    );
  }

  static ChatTheme _minimal(ColorScheme scheme, TextTheme text) {
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final flat = chat
        .mapBubbles(
          (b) => b.copyWith(color: scheme.surface, accentColor: scheme.outline),
        )
        .withMessageText(TextStyle(color: scheme.onSurfaceVariant));
    return flat.copyWith(
      outgoingBubble: flat.outgoingBubble.copyWith(
        color: scheme.surfaceContainer,
        textStyle: flat.incomingBubble.textStyle,
        metaStyle: flat.incomingBubble.metaStyle,
      ),
      composer: chat.composer.copyWith(
        inputColor: scheme.surface,
        inputRadius: 6,
        inputBorder: BorderSide(color: scheme.outlineVariant),
        sendButtonColor: scheme.onSurface,
        sendIconColor: scheme.surface,
      ),
      badge: chat.badge.copyWith(color: scheme.onSurface, radius: 4),
    );
  }

  static ChatTheme _cards(ColorScheme scheme, TextTheme text) {
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    return chat.copyWith(
      composer: chat.composer.copyWith(
        inputRadius: 14,
        inputBorder: BorderSide(color: scheme.outlineVariant),
      ),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(color: scheme.surfaceContainerLowest),
      ),
    );
  }

  @override
  String toString() => 'ChatPreset($name)';
}
