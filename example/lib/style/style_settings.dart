import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_scale_kit/flutter_scale_kit.dart';

/// Where the chat's screen scale comes from.
enum ScreenScale {
  /// Design sizes, only the zoom sliders apply.
  off,

  /// The built-in `ChatScale.byScreen()`, no package.
  byScreen,

  /// flutter_scale_kit: the same factors as `.w` and `.sp` in the app.
  scaleKit,
}

/// Live style of the example app: a [preset] plus the sheet's overrides,
/// turned into a [ChatStyle] by [chatStyle].
class StyleSettings extends ChangeNotifier {
  StyleSettings() {
    _load(ChatPreset.classic);
  }

  static final ChatScaler _byScreen = ChatScale.byScreen();

  late ChatPreset _preset;
  Color _seed = Colors.teal;
  bool _dark = false;
  ScreenScale _screen = ScreenScale.off;
  double _zoom = 1;
  double _textScale = 1;
  late double _messageFontSize;
  bool _greyText = false;
  late double _bubbleRadius;
  late bool _bubbleShadows;
  late bool _bubbleBorder;
  late ChatTiles _tiles;
  late double _tileRadius;
  late bool _squareAvatars;

  ChatPreset get preset => _preset;
  Color get seed => _seed;
  bool get dark => _dark;
  ScreenScale get screen => _screen;
  double get zoom => _zoom;
  double get textScale => _textScale;
  double get messageFontSize => _messageFontSize;
  bool get greyText => _greyText;
  double get bubbleRadius => _bubbleRadius;
  bool get bubbleShadows => _bubbleShadows;
  bool get bubbleBorder => _bubbleBorder;
  ChatTiles get tiles => _tiles;
  double get tileRadius => _tileRadius;
  bool get squareAvatars => _squareAvatars;

  void _load(ChatPreset preset) {
    _preset = preset;
    _seed = preset.seedColor ?? _seed;
    _messageFontSize = preset.messageStyle?.fontSize ?? 16;
    _greyText = false;
    _bubbleRadius = preset.bubbleRadius ?? 18;
    _bubbleShadows = preset.bubbleShadows ?? false;
    _bubbleBorder = preset.bubbleBorder ?? false;
    _tiles = preset.tiles ?? ChatTiles.plain;
    _tileRadius = preset.tileRadius ?? 16;
    _squareAvatars = preset.squareAvatars ?? false;
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Loads [preset] and its defaults; scale and dark mode are kept.
  void applyPreset(ChatPreset preset) => _set(() => _load(preset));

  void reset() => _set(() {
    _load(_preset);
    _zoom = 1;
    _textScale = 1;
  });

  /// Everything as on first launch, including the preset, color, dark mode
  /// and screen scale.
  void resetAll() => _set(() {
    _seed = Colors.teal;
    _dark = false;
    _screen = ScreenScale.off;
    _zoom = 1;
    _textScale = 1;
    _load(ChatPreset.classic);
  });

  set seed(Color value) => _set(() => _seed = value);
  set dark(bool value) => _set(() => _dark = value);
  set screen(ScreenScale value) => _set(() => _screen = value);
  set zoom(double value) => _set(() => _zoom = value);
  set textScale(double value) => _set(() => _textScale = value);
  set messageFontSize(double value) => _set(() => _messageFontSize = value);
  set greyText(bool value) => _set(() => _greyText = value);
  set bubbleRadius(double value) => _set(() => _bubbleRadius = value);
  set bubbleShadows(bool value) => _set(() => _bubbleShadows = value);
  set bubbleBorder(bool value) => _set(() => _bubbleBorder = value);
  set tiles(ChatTiles value) => _set(() => _tiles = value);
  set tileRadius(double value) => _set(() => _tileRadius = value);
  set squareAvatars(bool value) => _set(() => _squareAvatars = value);

  ThemeMode get themeMode => _dark ? ThemeMode.dark : ThemeMode.light;

  /// The app theme; the chat part is styled by [chatStyle] only.
  ThemeData theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  );

  /// Wraps a chat screen in the current settings.
  Widget chatStyle({required Widget child}) => ChatStyle(
    preset: _preset,
    seedColor: _seed,
    bubbleRadius: _bubbleRadius,
    bubbleShadows: _bubbleShadows,
    bubbleBorder: _bubbleBorder,
    messageStyle: TextStyle(
      fontSize: _messageFontSize,
      color: _greyText ? Colors.grey.shade600 : null,
    ),
    tiles: _tiles,
    tileRadius: _tileRadius,
    squareAvatars: _squareAvatars,
    scale: _scale,
    child: child,
  );

  // A method tear-off stays equal between builds, so ChatStyle reuses its
  // theme until a value really changes.
  ChatScale _scale(BuildContext context) {
    final screen = switch (_screen) {
      ScreenScale.off => ChatScale.none,
      ScreenScale.byScreen => _byScreen(context),
      ScreenScale.scaleKit => ChatScale(1.w, text: 1.sp),
    };
    return screen * ChatScale(_zoom, text: _zoom * _textScale);
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
