import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';

enum TileLayout { plain, divided, card }

/// A starting look. The sliders of the style sheet then override its
/// values; [base] covers what they do not (colors, gradients, wallpaper).
class ChatPreset {
  const ChatPreset({
    required this.name,
    required this.seed,
    this.base = _fallback,
    this.messageFontSize = 16,
    this.greyText = false,
    this.bubbleRadius = 18,
    this.bubbleShadows = false,
    this.bubbleBorder = false,
    this.tileLayout = TileLayout.plain,
    this.tileRadius = 16,
    this.squareAvatars = false,
  });

  final String name;
  final Color seed;
  final ChatTheme Function(ColorScheme scheme, TextTheme text) base;
  final double messageFontSize;
  final bool greyText;
  final double bubbleRadius;
  final bool bubbleShadows;
  final bool bubbleBorder;
  final TileLayout tileLayout;
  final double tileRadius;
  final bool squareAvatars;

  static ChatTheme _fallback(ColorScheme scheme, TextTheme text) =>
      ChatTheme.fallback(scheme, textTheme: text);

  static const classic = ChatPreset(name: 'Classic', seed: Colors.teal);

  static const whatsApp = ChatPreset(
    name: 'WhatsApp-like',
    seed: Color(0xFF25D366),
    base: _whatsApp,
    messageFontSize: 15,
    bubbleRadius: 8,
    bubbleShadows: true,
    tileLayout: TileLayout.divided,
  );

  static const telegram = ChatPreset(
    name: 'Telegram-like',
    seed: Color(0xFF2AABEE),
    base: _telegram,
    bubbleRadius: 16,
  );

  static const minimal = ChatPreset(
    name: 'Minimal grey',
    seed: Colors.blueGrey,
    base: _minimal,
    messageFontSize: 14,
    greyText: true,
    bubbleRadius: 6,
    bubbleBorder: true,
    tileLayout: TileLayout.divided,
    squareAvatars: true,
  );

  static const cards = ChatPreset(
    name: 'Cards',
    seed: Colors.indigo,
    base: _cards,
    bubbleRadius: 22,
    bubbleShadows: true,
    tileLayout: TileLayout.card,
    tileRadius: 20,
  );

  static const List<ChatPreset> all = [
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
    final flat = chat.mapBubbles(
      (b) => b.copyWith(color: scheme.surface, accentColor: scheme.outline),
    );
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
}

/// Live style of the example app: a [preset] plus the sheet's overrides.
class StyleSettings extends ChangeNotifier {
  StyleSettings() {
    _load(ChatPreset.classic);
  }

  late ChatPreset _preset;
  late Color _seed;
  bool _dark = false;
  double _scale = 1;
  double _textScale = 1;
  late double _messageFontSize;
  late bool _greyText;
  late double _bubbleRadius;
  late bool _bubbleShadows;
  late bool _bubbleBorder;
  late TileLayout _tileLayout;
  late double _tileRadius;
  late bool _squareAvatars;

  ChatPreset get preset => _preset;
  Color get seed => _seed;
  bool get dark => _dark;
  double get scale => _scale;
  double get textScale => _textScale;
  double get messageFontSize => _messageFontSize;
  bool get greyText => _greyText;
  double get bubbleRadius => _bubbleRadius;
  bool get bubbleShadows => _bubbleShadows;
  bool get bubbleBorder => _bubbleBorder;
  TileLayout get tileLayout => _tileLayout;
  double get tileRadius => _tileRadius;
  bool get squareAvatars => _squareAvatars;

  void _load(ChatPreset preset) {
    _preset = preset;
    _seed = preset.seed;
    _messageFontSize = preset.messageFontSize;
    _greyText = preset.greyText;
    _bubbleRadius = preset.bubbleRadius;
    _bubbleShadows = preset.bubbleShadows;
    _bubbleBorder = preset.bubbleBorder;
    _tileLayout = preset.tileLayout;
    _tileRadius = preset.tileRadius;
    _squareAvatars = preset.squareAvatars;
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Loads [preset] and its defaults; scale and dark mode are kept.
  void applyPreset(ChatPreset preset) => _set(() => _load(preset));

  void reset() => _set(() {
    _load(_preset);
    _scale = 1;
    _textScale = 1;
  });

  set seed(Color value) => _set(() => _seed = value);
  set dark(bool value) => _set(() => _dark = value);
  set scale(double value) => _set(() => _scale = value);
  set textScale(double value) => _set(() => _textScale = value);
  set messageFontSize(double value) => _set(() => _messageFontSize = value);
  set greyText(bool value) => _set(() => _greyText = value);
  set bubbleRadius(double value) => _set(() => _bubbleRadius = value);
  set bubbleShadows(bool value) => _set(() => _bubbleShadows = value);
  set bubbleBorder(bool value) => _set(() => _bubbleBorder = value);
  set tileLayout(TileLayout value) => _set(() => _tileLayout = value);
  set tileRadius(double value) => _set(() => _tileRadius = value);
  set squareAvatars(bool value) => _set(() => _squareAvatars = value);

  ThemeMode get themeMode => _dark ? ThemeMode.dark : ThemeMode.light;

  /// The app theme for [brightness], with the chat theme registered.
  ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme);
    return base.copyWith(extensions: [chatTheme(scheme, base.textTheme)]);
  }

  /// Preset, then the sheet's overrides, then the scale (always last: it
  /// multiplies everything set before it).
  ChatTheme chatTheme(ColorScheme scheme, TextTheme text) {
    var chat = _preset
        .base(scheme, text)
        .mapBubbles(
          (b) => b.copyWith(
            radius: _bubbleRadius,
            tailRadius: math.min(b.tailRadius, _bubbleRadius),
            shadows: _bubbleShadows
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : const [],
            border: _bubbleBorder
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
          ),
        )
        .withMessageText(
          TextStyle(
            fontSize: _messageFontSize,
            color: _greyText ? Colors.grey.shade600 : null,
          ),
        );

    final tile = chat.roomTile;
    chat = chat.copyWith(
      roomTile: switch (_tileLayout) {
        TileLayout.plain => tile,
        TileLayout.divided => tile.copyWith(
          divider: BorderSide(color: scheme.outlineVariant, width: 0.6),
        ),
        TileLayout.card => tile.copyWith(
          color: scheme.surfaceContainerLow,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_tileRadius),
          ),
        ),
      },
      avatar: _squareAvatars ? chat.avatar.copyWith(radius: 10) : null,
    );

    return chat.scaled(_scale, textFactor: _scale * _textScale);
  }
}

/// Makes [StyleSettings] reachable from every route.
class StyleScope extends InheritedNotifier<StyleSettings> {
  const StyleScope({
    required StyleSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  static StyleSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StyleScope>()!.notifier!;
}
