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
  /// A preset named [name]. Without [build] the base is
  /// `ChatTheme.fallback`; null options leave `ChatStyle`'s defaults.
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

  /// Makes the base theme from the chat's color scheme and text theme;
  /// the place for gradients, wallpapers and per-part colors.
  final ChatThemeFactory build;

  /// Default for `ChatStyle.bubbleRadius`: bubble corner radius.
  final double? bubbleRadius;

  /// Default for `ChatStyle.bubbleShadows`: a soft shadow under bubbles.
  final bool? bubbleShadows;

  /// Default for `ChatStyle.bubbleBorder`: a thin outline around bubbles.
  final bool? bubbleBorder;

  /// Merged into the message text of both bubbles.
  final TextStyle? messageStyle;

  /// Default for `ChatStyle.tiles`: layout of the inbox rows.
  final ChatTiles? tiles;

  /// Default for `ChatStyle.tileRadius`: corner radius of card rows.
  final double? tileRadius;

  /// Default for `ChatStyle.squareAvatars`: rounded squares instead of
  /// circles.
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

  /// The current WhatsApp look: pill-shaped bubbles without tails,
  /// frameless photos, a composer floating on the wallpaper and plain rows.
  static const whatsAppNew = ChatPreset(
    name: 'WhatsApp (new)',
    seedColor: Color(0xFF1DAA61),
    build: _whatsAppNew,
    messageStyle: TextStyle(fontSize: 15),
    bubbleRadius: 20,
    tiles: ChatTiles.plain,
  );

  /// Blue and grey bubbles on a plain background, an outlined input and a
  /// round blue send button.
  static const iMessage = ChatPreset(
    name: 'iMessage-like',
    seedColor: Color(0xFF007AFF),
    build: _iMessage,
    messageStyle: TextStyle(fontSize: 16),
    bubbleRadius: 20,
  );

  /// Blue to pink gradient bubbles for you, light grey ones for the others,
  /// tightly grouped.
  static const messenger = ChatPreset(
    name: 'Messenger-like',
    seedColor: Color(0xFF0084FF),
    build: _messenger,
    bubbleRadius: 20,
  );

  /// Frosted, see-through bubbles and input over an aurora gradient, in
  /// the spirit of Liquid Glass.
  static const glass = ChatPreset(
    name: 'Glass',
    seedColor: Color(0xFF6A5AE0),
    build: _glass,
    bubbleRadius: 22,
    tiles: ChatTiles.cards,
    tileRadius: 22,
  );

  /// Every built-in preset, for a style picker.
  static const List<ChatPreset> values = [
    classic,
    whatsApp,
    whatsAppNew,
    telegram,
    iMessage,
    messenger,
    minimal,
    cards,
    glass,
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

  static ChatTheme _whatsAppNew(ColorScheme scheme, TextTheme text) {
    final dark = scheme.brightness == Brightness.dark;
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    const green = Color(0xFF1DAA61);
    final ink = dark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A);
    final meta = dark ? const Color(0xFFA5A5A5) : const Color(0xFF5E5E5E);
    final wallpaper = dark ? const Color(0xFF161717) : const Color(0xFFF5F1EB);
    final paper = dark ? const Color(0xFF242626) : Colors.white;
    ChatBubbleStyle bubble(ChatBubbleStyle b, Color color) => b.copyWith(
      color: color,
      textStyle: b.textStyle.copyWith(color: ink),
      metaStyle: b.metaStyle.copyWith(color: meta),
      accentColor: green,
      tailRadius: 20,
    );
    ChatChipStyle chip(ChatChipStyle c) => c.copyWith(
      color: paper,
      textStyle: c.textStyle.copyWith(color: meta),
      radius: 16,
    );
    return chat.copyWith(
      outgoingBubble: bubble(
        chat.outgoingBubble,
        dark ? const Color(0xFF144D37) : const Color(0xFFD9FDD3),
      ),
      incomingBubble: bubble(chat.incomingBubble, paper),
      status: chat.status.copyWith(seenColor: const Color(0xFF53BDEB)),
      media: chat.media.copyWith(inset: 0),
      dateSeparator: chip(chat.dateSeparator),
      systemMessage: chip(chat.systemMessage),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(color: wallpaper),
      ),
      composer: chat.composer.copyWith(
        backgroundColor: wallpaper,
        inputColor: paper,
        inputRadius: 26,
        sendButtonColor: green,
        sendIconColor: Colors.white,
      ),
      badge: chat.badge.copyWith(color: green),
    );
  }

  static ChatTheme _iMessage(ColorScheme scheme, TextTheme text) {
    final dark = scheme.brightness == Brightness.dark;
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final blue = dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final grey = dark ? const Color(0xFF26252A) : const Color(0xFFE9E9EB);
    final ink = dark ? Colors.white : Colors.black;
    final page = dark ? Colors.black : Colors.white;
    final meta = dark ? const Color(0xFF98989F) : const Color(0xFF8E8E93);
    return chat.copyWith(
      outgoingBubble: chat.outgoingBubble.copyWith(
        color: blue,
        textStyle: chat.outgoingBubble.textStyle.copyWith(color: Colors.white),
        metaStyle: chat.outgoingBubble.metaStyle.copyWith(
          color: Colors.white70,
        ),
        accentColor: Colors.white,
        tailRadius: 6,
      ),
      incomingBubble: chat.incomingBubble.copyWith(
        color: grey,
        textStyle: chat.incomingBubble.textStyle.copyWith(color: ink),
        metaStyle: chat.incomingBubble.metaStyle.copyWith(color: meta),
        accentColor: blue,
        tailRadius: 6,
      ),
      status: chat.status.copyWith(seenColor: blue),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(color: page),
      ),
      composer: chat.composer.copyWith(
        backgroundColor: page,
        inputColor: page,
        inputRadius: 20,
        inputBorder: BorderSide(
          color: dark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC),
        ),
        sendButtonColor: blue,
        sendIconColor: Colors.white,
      ),
      dateSeparator: chat.dateSeparator.copyWith(
        color: Colors.transparent,
        textStyle: chat.dateSeparator.textStyle.copyWith(color: meta),
      ),
      badge: chat.badge.copyWith(color: blue),
    );
  }

  static ChatTheme _messenger(ColorScheme scheme, TextTheme text) {
    final dark = scheme.brightness == Brightness.dark;
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final grey = dark ? const Color(0xFF303030) : const Color(0xFFF0F0F0);
    final page = dark ? Colors.black : Colors.white;
    const blue = Color(0xFF0084FF);
    return chat.copyWith(
      outgoingBubble: chat.outgoingBubble.copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF0695FF), Color(0xFFA334FA), Color(0xFFFF6968)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        textStyle: chat.outgoingBubble.textStyle.copyWith(color: Colors.white),
        metaStyle: chat.outgoingBubble.metaStyle.copyWith(
          color: Colors.white70,
        ),
        accentColor: Colors.white,
      ),
      incomingBubble: chat.incomingBubble.copyWith(
        color: grey,
        textStyle: chat.incomingBubble.textStyle.copyWith(
          color: dark ? Colors.white : Colors.black,
        ),
        accentColor: blue,
      ),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(color: page),
      ),
      composer: chat.composer.copyWith(
        backgroundColor: page,
        inputColor: grey,
        iconColor: blue,
        sendButtonColor: blue,
        sendIconColor: Colors.white,
      ),
      badge: chat.badge.copyWith(color: blue),
    );
  }

  static ChatTheme _glass(ColorScheme scheme, TextTheme text) {
    final dark = scheme.brightness == Brightness.dark;
    final chat = ChatTheme.fallback(scheme, textTheme: text);
    final aurora = dark
        ? const [Color(0xFF1A1A40), Color(0xFF4B1D6B), Color(0xFF0F4C5C)]
        : const [Color(0xFFA1C4FD), Color(0xFFC2E9FB), Color(0xFFFBC2EB)];
    final frost = Colors.white.withValues(alpha: dark ? 0.12 : 0.55);
    final edge = BorderSide(
      color: Colors.white.withValues(alpha: dark ? 0.22 : 0.7),
    );
    final ink = dark ? Colors.white : const Color(0xFF1C1B1F);
    final shadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
    return chat.copyWith(
      outgoingBubble: chat.outgoingBubble.copyWith(
        color: scheme.primary.withValues(alpha: 0.78),
        border: edge,
        shadows: shadows,
      ),
      incomingBubble: chat.incomingBubble.copyWith(
        color: frost,
        textStyle: chat.incomingBubble.textStyle.copyWith(color: ink),
        metaStyle: chat.incomingBubble.metaStyle.copyWith(
          color: ink.withValues(alpha: 0.6),
        ),
        border: edge,
        shadows: shadows,
      ),
      dateSeparator: chat.dateSeparator.copyWith(
        color: frost,
        border: edge,
        textStyle: chat.dateSeparator.textStyle.copyWith(color: ink),
      ),
      systemMessage: chat.systemMessage.copyWith(
        color: frost,
        border: edge,
        textStyle: chat.systemMessage.textStyle.copyWith(color: ink),
      ),
      messageList: chat.messageList.copyWith(
        background: BoxDecoration(
          gradient: LinearGradient(
            colors: aurora,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      composer: chat.composer.copyWith(
        backgroundColor: aurora.last,
        inputColor: frost,
        inputBorder: edge,
        inputRadius: 26,
        textStyle: chat.composer.textStyle.copyWith(color: ink),
        hintStyle: chat.composer.hintStyle.copyWith(
          color: ink.withValues(alpha: 0.6),
        ),
        iconColor: ink.withValues(alpha: 0.75),
      ),
    );
  }

  @override
  String toString() => 'ChatPreset($name)';
}
