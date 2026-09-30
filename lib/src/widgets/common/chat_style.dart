import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_chat_kit/src/config/chat_preset.dart';
import 'package:flutter_chat_kit/src/config/chat_scale.dart';
import 'package:flutter_chat_kit/src/config/chat_styles.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Changes a whole [ChatTheme], for `ChatStyle.customize`.
typedef ChatThemeMapper = ChatTheme Function(ChatTheme theme);

/// Styles and scales every chat widget below it: wrap a chat screen, a
/// tab or the whole app.
///
/// With no options the chat follows the app's colors and fonts, light and
/// dark. Named options change the common things; [customize] reaches every
/// part of [ChatTheme]:
///
/// ```dart
/// ChatStyle(
///   preset: ChatPreset.whatsApp,
///   bubbleRadius: 16,
///   scale: (context) => ChatScale(1.w, text: 1.sp), // any scale package
///   customize: (theme) => theme.copyWith(
///     incomingBubble: theme.incomingBubble.copyWith(color: Colors.white),
///   ),
///   child: InboxView(
///     controller: inbox,
///     roomBuilder: (context, room) => RoomPage(roomId: room.id),
///   ),
/// )
/// ```
///
/// The theme is built in a fixed order: [preset] (or the app's
/// `ChatTheme`), the named options, [customize], then [scale]. A nested
/// `ChatStyle` changes only what it passes and inherits the rest.
///
/// Rooms opened through `InboxView.roomBuilder` or [ChatStyle.push] keep
/// this style and follow its changes. Sheets and dialogs opened from
/// inside keep it too.
class ChatStyle extends StatefulWidget {
  const ChatStyle({
    required this.child,
    this.preset,
    this.seedColor,
    this.bubbleRadius,
    this.bubbleShadows,
    this.bubbleBorder,
    this.messageStyle,
    this.fontFamily,
    this.tiles,
    this.tileRadius,
    this.squareAvatars,
    this.wallpaper,
    this.customize,
    this.scale,
    super.key,
  }) : _carried = null;

  const ChatStyle._carried(
    _ChatStyleOptions this._carried, {
    required this.child,
  }) : preset = null,
       seedColor = null,
       bubbleRadius = null,
       bubbleShadows = null,
       bubbleBorder = null,
       messageStyle = null,
       fontFamily = null,
       tiles = null,
       tileRadius = null,
       squareAvatars = null,
       wallpaper = null,
       customize = null,
       scale = null;

  final Widget child;

  /// A ready-made look; its values are defaults for the options below.
  /// Replaces the app's registered `ChatTheme`.
  final ChatPreset? preset;

  /// Builds the chat colors from this color (`ColorScheme.fromSeed`, in
  /// the app's brightness) instead of the app's colors.
  final Color? seedColor;

  /// Corner radius of the message bubbles.
  final double? bubbleRadius;

  /// A soft shadow under the bubbles.
  final bool? bubbleShadows;

  /// A thin outline around the bubbles.
  final bool? bubbleBorder;

  /// Merged into the message text of both bubbles, for example
  /// `TextStyle(fontSize: 15, color: Colors.grey)`.
  final TextStyle? messageStyle;

  /// Font of every chat text.
  final String? fontFamily;

  /// Inbox rows: plain, divided or cards.
  final ChatTiles? tiles;

  /// Corner radius of card rows.
  final double? tileRadius;

  /// Rounded squares instead of circles.
  final bool? squareAvatars;

  /// Painted behind the messages.
  final Decoration? wallpaper;

  /// Last change before scaling, with access to every part of the theme.
  /// Nested styles run the outer [customize] first.
  final ChatThemeMapper? customize;

  /// The chat's size for the current screen; see [ChatScale].
  final ChatScaler? scale;

  final _ChatStyleOptions? _carried;

  /// The scale of the nearest [ChatStyle], or [ChatScale.none].
  static ChatScale scaleOf(BuildContext context) =>
      _ChatStyleScope.maybeOf(context)?.scale ?? ChatScale.none;

  /// Wraps a page shown outside this widget (a pushed route) in the
  /// nearest style, following its later changes. Returns the page as is
  /// when there is no [ChatStyle]. Capture it before pushing:
  ///
  /// ```dart
  /// final keepStyle = ChatStyle.carry(context);
  /// router.push(... builder: (_) => keepStyle(const RoomPage()));
  /// ```
  static Widget Function(Widget page) carry(BuildContext context) {
    final scope = _ChatStyleScope.maybeOf(context, listen: false);
    if (scope == null) return (page) => page;
    final link = scope.link;
    return (page) => ValueListenableBuilder<_ChatStyleOptions>(
      valueListenable: link,
      builder: (context, options, page) =>
          ChatStyle._carried(options, child: page!),
      child: page,
    );
  }

  /// Pushes a page that keeps the nearest style, like
  /// `Navigator.push(context, MaterialPageRoute(builder: builder))`.
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    final keepStyle = carry(context);
    return Navigator.of(context).push(
      MaterialPageRoute<T>(
        builder: (_) => keepStyle(Builder(builder: builder)),
      ),
    );
  }

  @override
  State<ChatStyle> createState() => _ChatStyleState();
}

class _ChatStyleState extends State<ChatStyle> {
  // Not disposed: pages pushed from here keep listening after this widget
  // is gone, and keep its last style.
  ValueNotifier<_ChatStyleOptions>? _link;

  ThemeData? _theme;
  ChatTheme? _ambient;
  _ChatStyleOptions? _options;
  ChatScale? _scale;
  ChatTheme? _output;

  @override
  Widget build(BuildContext context) {
    final parent = _ChatStyleScope.maybeOf(context);
    final options =
        widget._carried ??
        (parent?.options ?? _ChatStyleOptions.empty).merge(widget);
    final theme = Theme.of(context);
    var ambient = theme.extension<ChatTheme>();
    // The outer style's result is not a base: start from what it started
    // from, so nothing is applied (or scaled) twice.
    if (parent != null && identical(ambient, parent.output)) {
      ambient = parent.ambient;
    }

    var scale = ChatScale.none;
    if (options.scale case final scaler?) {
      MediaQuery.maybeSizeOf(context);
      scale = scaler(context);
    }

    final output = _resolve(theme, ambient, options, scale);
    final link = _publish(options);
    return _ChatStyleScope(
      options: options,
      ambient: ambient,
      output: output,
      scale: scale,
      link: link,
      child: Theme(
        data: theme.copyWith(extensions: [...theme.extensions.values, output]),
        child: widget.child,
      ),
    );
  }

  ValueNotifier<_ChatStyleOptions> _publish(_ChatStyleOptions options) {
    final link = _link;
    if (link == null) return _link = ValueNotifier(options);
    if (link.value != options) {
      // Pages listening elsewhere in the tree rebuild on the next frame,
      // not in the middle of this one.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        link.value = options;
      });
    }
    return link;
  }

  ChatTheme _resolve(
    ThemeData theme,
    ChatTheme? ambient,
    _ChatStyleOptions options,
    ChatScale scale,
  ) {
    final cached = _output;
    if (cached != null &&
        identical(theme, _theme) &&
        identical(ambient, _ambient) &&
        options == _options &&
        scale == _scale) {
      return cached;
    }
    _theme = theme;
    _ambient = ambient;
    _options = options;
    _scale = scale;
    return _output = options.apply(theme, ambient, scale);
  }
}

@immutable
class _ChatStyleOptions {
  const _ChatStyleOptions({
    this.preset,
    this.seedColor,
    this.bubbleRadius,
    this.bubbleShadows,
    this.bubbleBorder,
    this.messageStyle,
    this.fontFamily,
    this.tiles,
    this.tileRadius,
    this.squareAvatars,
    this.wallpaper,
    this.customize = const [],
    this.scale,
  });

  static const empty = _ChatStyleOptions();

  final ChatPreset? preset;
  final Color? seedColor;
  final double? bubbleRadius;
  final bool? bubbleShadows;
  final bool? bubbleBorder;
  final TextStyle? messageStyle;
  final String? fontFamily;
  final ChatTiles? tiles;
  final double? tileRadius;
  final bool? squareAvatars;
  final Decoration? wallpaper;
  final List<ChatThemeMapper> customize;
  final ChatScaler? scale;

  static const _shadows = [
    BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  _ChatStyleOptions merge(ChatStyle w) {
    final customize = w.customize;
    return _ChatStyleOptions(
      preset: w.preset ?? preset,
      seedColor: w.seedColor ?? seedColor,
      bubbleRadius: w.bubbleRadius ?? bubbleRadius,
      bubbleShadows: w.bubbleShadows ?? bubbleShadows,
      bubbleBorder: w.bubbleBorder ?? bubbleBorder,
      messageStyle: messageStyle?.merge(w.messageStyle) ?? w.messageStyle,
      fontFamily: w.fontFamily ?? fontFamily,
      tiles: w.tiles ?? tiles,
      tileRadius: w.tileRadius ?? tileRadius,
      squareAvatars: w.squareAvatars ?? squareAvatars,
      wallpaper: w.wallpaper ?? wallpaper,
      customize: customize == null
          ? this.customize
          : [...this.customize, customize],
      scale: w.scale ?? scale,
    );
  }

  ChatTheme apply(ThemeData theme, ChatTheme? ambient, ChatScale scale) {
    final preset = this.preset;
    final seed = seedColor ?? preset?.seedColor;
    final scheme = seed == null
        ? theme.colorScheme
        : ColorScheme.fromSeed(
            seedColor: seed,
            brightness: theme.colorScheme.brightness,
          );
    final text = theme.textTheme;
    var chat = preset != null
        ? preset.build(scheme, text)
        : seed != null || ambient == null
        ? ChatTheme.fallback(scheme, textTheme: text)
        : ambient;

    final radius = bubbleRadius ?? preset?.bubbleRadius;
    final shadows = bubbleShadows ?? preset?.bubbleShadows;
    final border = bubbleBorder ?? preset?.bubbleBorder;
    if (radius != null || shadows != null || border != null) {
      chat = chat.mapBubbles(
        (b) => b.copyWith(
          radius: radius,
          tailRadius: radius == null ? null : math.min(b.tailRadius, radius),
          shadows: shadows == null
              ? null
              : shadows
              ? _shadows
              : const <BoxShadow>[],
          border: border == null
              ? null
              : border
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
      );
    }

    final message = preset?.messageStyle?.merge(messageStyle) ?? messageStyle;
    if (message != null) chat = chat.withMessageText(message);

    final tiles = this.tiles ?? preset?.tiles;
    final tileRadius = this.tileRadius ?? preset?.tileRadius;
    if (tiles != null) {
      chat = chat.copyWith(
        roomTile: _layout(chat.roomTile, tiles, scheme, tileRadius),
      );
    } else if (tileRadius != null) {
      final shape = chat.roomTile.shape;
      if (shape is RoundedRectangleBorder) {
        chat = chat.copyWith(
          roomTile: chat.roomTile.copyWith(
            shape: shape.copyWith(
              borderRadius: BorderRadius.circular(tileRadius),
            ),
          ),
        );
      }
    }

    if (squareAvatars ?? preset?.squareAvatars case final square?) {
      final a = chat.avatar;
      chat = chat.copyWith(
        avatar: ChatAvatarStyle(
          backgroundColor: a.backgroundColor,
          foregroundColor: a.foregroundColor,
          radius: square ? 10 : null,
          border: a.border,
          onlineColor: a.onlineColor,
        ),
      );
    }

    if (wallpaper case final wallpaper?) {
      chat = chat.copyWith(
        messageList: chat.messageList.copyWith(background: wallpaper),
      );
    }
    if (fontFamily case final family?) {
      chat = chat.mapText((style) => style.copyWith(fontFamily: family));
    }
    for (final change in customize) {
      chat = change(chat);
    }
    if (!scale.isNone) {
      chat = chat.scaled(scale.size, textFactor: scale.text);
    }
    return chat;
  }

  static ChatRoomTileStyle _layout(
    ChatRoomTileStyle t,
    ChatTiles tiles,
    ColorScheme scheme,
    double? radius,
  ) {
    final plain = ChatRoomTileStyle(
      titleStyle: t.titleStyle,
      unreadTitleStyle: t.unreadTitleStyle,
      subtitleStyle: t.subtitleStyle,
      unreadSubtitleStyle: t.unreadSubtitleStyle,
      typingStyle: t.typingStyle,
      timeStyle: t.timeStyle,
      unreadTimeStyle: t.unreadTimeStyle,
      iconColor: t.iconColor,
      avatarSize: t.avatarSize,
      gap: t.gap,
      lineGap: t.lineGap,
      trailingGap: t.trailingGap,
      iconSize: t.iconSize,
    );
    return switch (tiles) {
      ChatTiles.plain => plain,
      ChatTiles.divided => plain.copyWith(
        divider: BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      ChatTiles.cards => plain.copyWith(
        color: scheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius ?? 16),
        ),
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is _ChatStyleOptions &&
      other.preset == preset &&
      other.seedColor == seedColor &&
      other.bubbleRadius == bubbleRadius &&
      other.bubbleShadows == bubbleShadows &&
      other.bubbleBorder == bubbleBorder &&
      other.messageStyle == messageStyle &&
      other.fontFamily == fontFamily &&
      other.tiles == tiles &&
      other.tileRadius == tileRadius &&
      other.squareAvatars == squareAvatars &&
      other.wallpaper == wallpaper &&
      listEquals(other.customize, customize) &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    preset,
    seedColor,
    bubbleRadius,
    bubbleShadows,
    bubbleBorder,
    messageStyle,
    fontFamily,
    tiles,
    tileRadius,
    squareAvatars,
    wallpaper,
    Object.hashAll(customize),
    scale,
  );
}

class _ChatStyleScope extends InheritedTheme {
  const _ChatStyleScope({
    required this.options,
    required this.ambient,
    required this.output,
    required this.scale,
    required this.link,
    required super.child,
  });

  final _ChatStyleOptions options;

  /// The theme the style started from (null: none registered).
  final ChatTheme? ambient;
  final ChatTheme output;
  final ChatScale scale;
  final ValueNotifier<_ChatStyleOptions> link;

  static _ChatStyleScope? maybeOf(BuildContext context, {bool listen = true}) =>
      listen
      ? context.dependOnInheritedWidgetOfExactType<_ChatStyleScope>()
      : context.getInheritedWidgetOfExactType<_ChatStyleScope>();

  @override
  Widget wrap(BuildContext context, Widget child) => _ChatStyleScope(
    options: options,
    ambient: ambient,
    output: output,
    scale: scale,
    link: link,
    child: child,
  );

  @override
  bool updateShouldNotify(_ChatStyleScope oldWidget) =>
      options != oldWidget.options ||
      scale != oldWidget.scale ||
      !identical(output, oldWidget.output) ||
      !identical(ambient, oldWidget.ambient) ||
      !identical(link, oldWidget.link);
}
