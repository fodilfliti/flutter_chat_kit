import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Rewrites a text style; used by `mapText` on every style.
typedef ChatTextMapper = TextStyle Function(TextStyle style);

TextStyle _font(TextStyle style, double factor) {
  final size = style.fontSize;
  return size == null || factor == 1
      ? style
      : style.copyWith(fontSize: size * factor);
}

BorderSide _side(BorderSide side, double factor) =>
    side.copyWith(width: side.width * factor);

List<BoxShadow> _shadows(List<BoxShadow> shadows, double factor) => [
  for (final shadow in shadows) shadow.scale(factor),
];

double _d(double a, double b, double t) => lerpDouble(a, b, t)!;

Color _c(Color a, Color b, double t) => Color.lerp(a, b, t)!;

TextStyle _t(TextStyle a, TextStyle b, double t) => lerpChatText(a, b, t);

/// [TextStyle.lerp] that switches halfway instead of failing when [a] and
/// [b] differ in `inherit`, as a plain `TextStyle(...)` override does.
TextStyle lerpChatText(TextStyle a, TextStyle b, double t) {
  if (a.inherit != b.inherit) return t < 0.5 ? a : b;
  return TextStyle.lerp(a, b, t)!;
}

EdgeInsets _e(EdgeInsets a, EdgeInsets b, double t) =>
    EdgeInsets.lerp(a, b, t)!;

BorderSide _b(BorderSide a, BorderSide b, double t) => BorderSide.lerp(a, b, t);

class _Text {
  _Text(TextTheme? theme)
    : text = theme ?? Typography.material2021().englishLike;

  final TextTheme text;

  TextStyle get body => text.bodyLarge ?? const TextStyle(fontSize: 16);
  TextStyle get medium => text.bodyMedium ?? body;
  TextStyle get small => text.labelSmall ?? const TextStyle(fontSize: 11);
  TextStyle get label => text.labelMedium ?? const TextStyle(fontSize: 12);
  TextStyle get title => text.titleMedium ?? body;
  TextStyle get caption => text.bodySmall ?? label;
}

/// One side's bubbles: the outgoing (current user) or incoming style.
@immutable
class ChatBubbleStyle {
  const ChatBubbleStyle({
    required this.color,
    required this.textStyle,
    required this.metaStyle,
    required this.accentColor,
    this.gradient,
    this.radius = 18,
    this.tailRadius = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.border = BorderSide.none,
    this.shadows = const [],
  });

  factory ChatBubbleStyle.outgoing(ColorScheme scheme, {TextTheme? textTheme}) {
    final t = _Text(textTheme);
    return ChatBubbleStyle(
      color: scheme.primary,
      textStyle: t.body.copyWith(color: scheme.onPrimary),
      metaStyle: t.small.copyWith(
        color: scheme.onPrimary.withValues(alpha: 0.72),
      ),
      accentColor: scheme.onPrimary,
    );
  }

  factory ChatBubbleStyle.incoming(ColorScheme scheme, {TextTheme? textTheme}) {
    final t = _Text(textTheme);
    return ChatBubbleStyle(
      color: scheme.surfaceContainerHighest,
      textStyle: t.body.copyWith(color: scheme.onSurface),
      metaStyle: t.small.copyWith(color: scheme.onSurfaceVariant),
      accentColor: scheme.secondary,
    );
  }

  final Color color;

  /// Painted instead of [color] when set.
  final Gradient? gradient;
  final TextStyle textStyle;

  /// Time, "edited" label and status ticks.
  final TextStyle metaStyle;

  /// Reply bar and voice progress inside the bubble.
  final Color accentColor;
  final double radius;

  /// Corners facing the rest of a group, and the bottom corner on the
  /// author's side.
  final double tailRadius;
  final EdgeInsets padding;
  final BorderSide border;
  final List<BoxShadow> shadows;

  ChatBubbleStyle copyWith({
    Color? color,
    Gradient? gradient,
    TextStyle? textStyle,
    TextStyle? metaStyle,
    Color? accentColor,
    double? radius,
    double? tailRadius,
    EdgeInsets? padding,
    BorderSide? border,
    List<BoxShadow>? shadows,
  }) {
    return ChatBubbleStyle(
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      textStyle: textStyle ?? this.textStyle,
      metaStyle: metaStyle ?? this.metaStyle,
      accentColor: accentColor ?? this.accentColor,
      radius: radius ?? this.radius,
      tailRadius: tailRadius ?? this.tailRadius,
      padding: padding ?? this.padding,
      border: border ?? this.border,
      shadows: shadows ?? this.shadows,
    );
  }

  ChatBubbleStyle mapText(ChatTextMapper map) =>
      copyWith(textStyle: map(textStyle), metaStyle: map(metaStyle));

  ChatBubbleStyle scaled(double factor, {double? textFactor}) {
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      radius: radius * factor,
      tailRadius: tailRadius * factor,
      padding: padding * factor,
      border: _side(border, factor),
      shadows: _shadows(shadows, factor),
    );
  }

  ChatBubbleStyle lerp(ChatBubbleStyle b, double t) {
    final a = this;
    return ChatBubbleStyle(
      color: _c(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      textStyle: _t(a.textStyle, b.textStyle, t),
      metaStyle: _t(a.metaStyle, b.metaStyle, t),
      accentColor: _c(a.accentColor, b.accentColor, t),
      radius: _d(a.radius, b.radius, t),
      tailRadius: _d(a.tailRadius, b.tailRadius, t),
      padding: _e(a.padding, b.padding, t),
      border: _b(a.border, b.border, t),
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
    );
  }
}

/// Layout of the message list: spacing, bubble width, avatars, author
/// names and the highlight / selection background.
@immutable
class ChatMessageListStyle {
  const ChatMessageListStyle({
    required this.authorNameStyle,
    required this.highlightColor,
    required this.selectedColor,
    required this.selectionColor,
    this.background,
    this.padding = const EdgeInsets.all(8),
    this.maxBubbleWidthFactor = 0.78,
    this.messageSpacing = 2,
    this.groupSpacing = 10,
    this.avatarSize = 32,
    this.avatarGap = 6,
    this.authorNamePadding = const EdgeInsetsDirectional.only(
      start: 4,
      bottom: 2,
    ),
    this.selectionIconSize = 22,
  });

  factory ChatMessageListStyle.fallback(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    final t = _Text(textTheme);
    return ChatMessageListStyle(
      authorNameStyle: t.label.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      highlightColor: scheme.primary.withValues(alpha: 0.16),
      selectedColor: scheme.primary.withValues(alpha: 0.10),
      selectionColor: scheme.primary,
    );
  }

  final TextStyle authorNameStyle;

  /// Flash behind a message reached by jump-to-message.
  final Color highlightColor;

  /// Background of selected messages.
  final Color selectedColor;

  /// The checked selection circle.
  final Color selectionColor;

  /// Painted behind the messages of `ChatRoomView` (color, gradient or
  /// wallpaper image); null shows the scaffold background.
  final Decoration? background;
  final EdgeInsets padding;

  /// Bubble width as a fraction of the list width.
  final double maxBubbleWidthFactor;

  /// Gap between messages of one group.
  final double messageSpacing;

  /// Gap between groups.
  final double groupSpacing;
  final double avatarSize;

  /// Between the avatar column and the bubble.
  final double avatarGap;

  /// Around the author name of incoming messages; mirrored for outgoing.
  final EdgeInsetsDirectional authorNamePadding;
  final double selectionIconSize;

  ChatMessageListStyle copyWith({
    TextStyle? authorNameStyle,
    Color? highlightColor,
    Color? selectedColor,
    Color? selectionColor,
    Decoration? background,
    EdgeInsets? padding,
    double? maxBubbleWidthFactor,
    double? messageSpacing,
    double? groupSpacing,
    double? avatarSize,
    double? avatarGap,
    EdgeInsetsDirectional? authorNamePadding,
    double? selectionIconSize,
  }) {
    return ChatMessageListStyle(
      authorNameStyle: authorNameStyle ?? this.authorNameStyle,
      highlightColor: highlightColor ?? this.highlightColor,
      selectedColor: selectedColor ?? this.selectedColor,
      selectionColor: selectionColor ?? this.selectionColor,
      background: background ?? this.background,
      padding: padding ?? this.padding,
      maxBubbleWidthFactor: maxBubbleWidthFactor ?? this.maxBubbleWidthFactor,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      groupSpacing: groupSpacing ?? this.groupSpacing,
      avatarSize: avatarSize ?? this.avatarSize,
      avatarGap: avatarGap ?? this.avatarGap,
      authorNamePadding: authorNamePadding ?? this.authorNamePadding,
      selectionIconSize: selectionIconSize ?? this.selectionIconSize,
    );
  }

  ChatMessageListStyle mapText(ChatTextMapper map) =>
      copyWith(authorNameStyle: map(authorNameStyle));

  ChatMessageListStyle scaled(double factor, {double? textFactor}) {
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      padding: padding * factor,
      messageSpacing: messageSpacing * factor,
      groupSpacing: groupSpacing * factor,
      avatarSize: avatarSize * factor,
      avatarGap: avatarGap * factor,
      authorNamePadding: authorNamePadding * factor,
      selectionIconSize: selectionIconSize * factor,
    );
  }

  ChatMessageListStyle lerp(ChatMessageListStyle b, double t) {
    final a = this;
    return ChatMessageListStyle(
      authorNameStyle: _t(a.authorNameStyle, b.authorNameStyle, t),
      highlightColor: _c(a.highlightColor, b.highlightColor, t),
      selectedColor: _c(a.selectedColor, b.selectedColor, t),
      selectionColor: _c(a.selectionColor, b.selectionColor, t),
      background: Decoration.lerp(a.background, b.background, t),
      padding: _e(a.padding, b.padding, t),
      maxBubbleWidthFactor: _d(
        a.maxBubbleWidthFactor,
        b.maxBubbleWidthFactor,
        t,
      ),
      messageSpacing: _d(a.messageSpacing, b.messageSpacing, t),
      groupSpacing: _d(a.groupSpacing, b.groupSpacing, t),
      avatarSize: _d(a.avatarSize, b.avatarSize, t),
      avatarGap: _d(a.avatarGap, b.avatarGap, t),
      authorNamePadding: EdgeInsetsDirectional.lerp(
        a.authorNamePadding,
        b.authorNamePadding,
        t,
      )!,
      selectionIconSize: _d(a.selectionIconSize, b.selectionIconSize, t),
    );
  }
}

/// Delivery ticks of the current user's messages.
@immutable
class ChatStatusStyle {
  const ChatStatusStyle({
    required this.seenColor,
    required this.failedColor,
    this.color,
    this.iconSize = 14,
  });

  factory ChatStatusStyle.fallback(ColorScheme scheme) =>
      ChatStatusStyle(seenColor: scheme.tertiary, failedColor: scheme.error);

  /// Pending, sent and delivered; null uses the bubble's meta color.
  final Color? color;
  final Color seenColor;

  /// Failed tick and the "not sent" notice.
  final Color failedColor;
  final double iconSize;

  ChatStatusStyle copyWith({
    Color? color,
    Color? seenColor,
    Color? failedColor,
    double? iconSize,
  }) {
    return ChatStatusStyle(
      color: color ?? this.color,
      seenColor: seenColor ?? this.seenColor,
      failedColor: failedColor ?? this.failedColor,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  ChatStatusStyle scaled(double factor) =>
      copyWith(iconSize: iconSize * factor);

  ChatStatusStyle lerp(ChatStatusStyle b, double t) {
    final a = this;
    return ChatStatusStyle(
      color: Color.lerp(a.color, b.color, t),
      seenColor: _c(a.seenColor, b.seenColor, t),
      failedColor: _c(a.failedColor, b.failedColor, t),
      iconSize: _d(a.iconSize, b.iconSize, t),
    );
  }
}

/// A rounded label: date separators and system messages. For the unread
/// divider, [color] is the line and [padding] spaces the label from it.
@immutable
class ChatChipStyle {
  const ChatChipStyle({
    required this.color,
    required this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.margin = EdgeInsets.zero,
    this.radius = 12,
    this.border = BorderSide.none,
  });

  factory ChatChipStyle.dateSeparator(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    return ChatChipStyle(
      color: scheme.surfaceContainerHigh,
      textStyle: _Text(
        textTheme,
      ).label.copyWith(color: scheme.onSurfaceVariant),
      margin: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  factory ChatChipStyle.systemMessage(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    return ChatChipStyle(
      color: scheme.surfaceContainerHigh,
      textStyle: _Text(
        textTheme,
      ).label.copyWith(color: scheme.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  factory ChatChipStyle.unreadDivider(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    return ChatChipStyle(
      color: scheme.primary.withValues(alpha: 0.4),
      textStyle: _Text(textTheme).label.copyWith(color: scheme.primary),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  final Color color;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final BorderSide border;

  ChatChipStyle copyWith({
    Color? color,
    TextStyle? textStyle,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? radius,
    BorderSide? border,
  }) {
    return ChatChipStyle(
      color: color ?? this.color,
      textStyle: textStyle ?? this.textStyle,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      radius: radius ?? this.radius,
      border: border ?? this.border,
    );
  }

  ChatChipStyle mapText(ChatTextMapper map) =>
      copyWith(textStyle: map(textStyle));

  ChatChipStyle scaled(double factor, {double? textFactor}) {
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      padding: padding * factor,
      margin: margin * factor,
      radius: radius * factor,
      border: _side(border, factor),
    );
  }

  ChatChipStyle lerp(ChatChipStyle b, double t) {
    final a = this;
    return ChatChipStyle(
      color: _c(a.color, b.color, t),
      textStyle: _t(a.textStyle, b.textStyle, t),
      padding: _e(a.padding, b.padding, t),
      margin: _e(a.margin, b.margin, t),
      radius: _d(a.radius, b.radius, t),
      border: _b(a.border, b.border, t),
    );
  }
}

/// Reaction chips under a message.
@immutable
class ChatReactionStyle {
  const ChatReactionStyle({
    required this.color,
    required this.mineColor,
    required this.textStyle,
    this.emojiSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.radius = 999,
    this.border = BorderSide.none,
    this.mineBorder = BorderSide.none,
    this.spacing = 4,
  });

  factory ChatReactionStyle.fallback(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    return ChatReactionStyle(
      color: scheme.surfaceContainerHigh,
      mineColor: scheme.primaryContainer,
      textStyle: _Text(
        textTheme,
      ).small.copyWith(color: scheme.onSurfaceVariant),
    );
  }

  final Color color;

  /// Reactions the current user added.
  final Color mineColor;

  /// The count next to the emoji.
  final TextStyle textStyle;
  final double emojiSize;
  final EdgeInsets padding;
  final double radius;
  final BorderSide border;
  final BorderSide mineBorder;

  /// Between chips.
  final double spacing;

  ChatReactionStyle copyWith({
    Color? color,
    Color? mineColor,
    TextStyle? textStyle,
    double? emojiSize,
    EdgeInsets? padding,
    double? radius,
    BorderSide? border,
    BorderSide? mineBorder,
    double? spacing,
  }) {
    return ChatReactionStyle(
      color: color ?? this.color,
      mineColor: mineColor ?? this.mineColor,
      textStyle: textStyle ?? this.textStyle,
      emojiSize: emojiSize ?? this.emojiSize,
      padding: padding ?? this.padding,
      radius: radius ?? this.radius,
      border: border ?? this.border,
      mineBorder: mineBorder ?? this.mineBorder,
      spacing: spacing ?? this.spacing,
    );
  }

  ChatReactionStyle mapText(ChatTextMapper map) =>
      copyWith(textStyle: map(textStyle));

  ChatReactionStyle scaled(double factor, {double? textFactor}) {
    final text = textFactor ?? factor;
    return mapText((s) => _font(s, text)).copyWith(
      emojiSize: emojiSize * text,
      padding: padding * factor,
      radius: radius * factor,
      border: _side(border, factor),
      mineBorder: _side(mineBorder, factor),
      spacing: spacing * factor,
    );
  }

  ChatReactionStyle lerp(ChatReactionStyle b, double t) {
    final a = this;
    return ChatReactionStyle(
      color: _c(a.color, b.color, t),
      mineColor: _c(a.mineColor, b.mineColor, t),
      textStyle: _t(a.textStyle, b.textStyle, t),
      emojiSize: _d(a.emojiSize, b.emojiSize, t),
      padding: _e(a.padding, b.padding, t),
      radius: _d(a.radius, b.radius, t),
      border: _b(a.border, b.border, t),
      mineBorder: _b(a.mineBorder, b.mineBorder, t),
      spacing: _d(a.spacing, b.spacing, t),
    );
  }
}

/// A quoted message, inside bubbles and above the composer.
@immutable
class ChatReplyStyle {
  const ChatReplyStyle({
    required this.accentColor,
    this.backgroundColor,
    this.accentWidth = 3,
    this.radius = 8,
    this.padding = const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
    this.textScale = 0.85,
  });

  factory ChatReplyStyle.fallback(ColorScheme scheme) =>
      ChatReplyStyle(accentColor: scheme.secondary);

  /// Above the composer; bubbles use `ChatBubbleStyle.accentColor`.
  final Color accentColor;

  /// Null tints the accent color.
  final Color? backgroundColor;
  final double accentWidth;
  final double radius;
  final EdgeInsetsDirectional padding;

  /// Snippet font size relative to the surrounding text.
  final double textScale;

  ChatReplyStyle copyWith({
    Color? accentColor,
    Color? backgroundColor,
    double? accentWidth,
    double? radius,
    EdgeInsetsDirectional? padding,
    double? textScale,
  }) {
    return ChatReplyStyle(
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      accentWidth: accentWidth ?? this.accentWidth,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      textScale: textScale ?? this.textScale,
    );
  }

  ChatReplyStyle scaled(double factor) => copyWith(
    accentWidth: accentWidth * factor,
    radius: radius * factor,
    padding: padding * factor,
  );

  ChatReplyStyle lerp(ChatReplyStyle b, double t) {
    final a = this;
    return ChatReplyStyle(
      accentColor: _c(a.accentColor, b.accentColor, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      accentWidth: _d(a.accentWidth, b.accentWidth, t),
      radius: _d(a.radius, b.radius, t),
      padding: EdgeInsetsDirectional.lerp(a.padding, b.padding, t)!,
      textScale: _d(a.textScale, b.textScale, t),
    );
  }
}

/// Image and video bubbles.
@immutable
class ChatMediaStyle {
  const ChatMediaStyle({
    this.maxWidth = 300,
    this.inset = 3,
    this.overlayColor = const Color(0x73000000),
    this.overlayForegroundColor = const Color(0xFFFFFFFF),
    this.overlayRadius = 10,
    this.overlayPadding = const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 2,
    ),
  });

  final double maxWidth;

  /// Gap between the media and the bubble edge.
  final double inset;

  /// Pill behind the time on media without a caption, and the video
  /// duration.
  final Color overlayColor;
  final Color overlayForegroundColor;
  final double overlayRadius;
  final EdgeInsets overlayPadding;

  ChatMediaStyle copyWith({
    double? maxWidth,
    double? inset,
    Color? overlayColor,
    Color? overlayForegroundColor,
    double? overlayRadius,
    EdgeInsets? overlayPadding,
  }) {
    return ChatMediaStyle(
      maxWidth: maxWidth ?? this.maxWidth,
      inset: inset ?? this.inset,
      overlayColor: overlayColor ?? this.overlayColor,
      overlayForegroundColor:
          overlayForegroundColor ?? this.overlayForegroundColor,
      overlayRadius: overlayRadius ?? this.overlayRadius,
      overlayPadding: overlayPadding ?? this.overlayPadding,
    );
  }

  ChatMediaStyle scaled(double factor) => copyWith(
    maxWidth: maxWidth * factor,
    inset: inset * factor,
    overlayRadius: overlayRadius * factor,
    overlayPadding: overlayPadding * factor,
  );

  ChatMediaStyle lerp(ChatMediaStyle b, double t) {
    final a = this;
    return ChatMediaStyle(
      maxWidth: _d(a.maxWidth, b.maxWidth, t),
      inset: _d(a.inset, b.inset, t),
      overlayColor: _c(a.overlayColor, b.overlayColor, t),
      overlayForegroundColor: _c(
        a.overlayForegroundColor,
        b.overlayForegroundColor,
        t,
      ),
      overlayRadius: _d(a.overlayRadius, b.overlayRadius, t),
      overlayPadding: _e(a.overlayPadding, b.overlayPadding, t),
    );
  }
}

/// The input bar, also used by the inbox search field.
@immutable
class ChatComposerStyle {
  const ChatComposerStyle({
    required this.backgroundColor,
    required this.inputColor,
    required this.textStyle,
    required this.hintStyle,
    required this.iconColor,
    required this.sendButtonColor,
    required this.sendIconColor,
    this.padding = const EdgeInsets.fromLTRB(6, 6, 8, 6),
    this.inputRadius = 22,
    this.inputBorder = BorderSide.none,
    this.inputPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 11,
    ),
    this.buttonSize = 44,
    this.iconSize = 24,
    this.border = BorderSide.none,
  });

  factory ChatComposerStyle.fallback(
    ColorScheme scheme, {
    TextTheme? textTheme,
  }) {
    final t = _Text(textTheme);
    return ChatComposerStyle(
      backgroundColor: scheme.surface,
      inputColor: scheme.surfaceContainerHigh,
      textStyle: t.body.copyWith(color: scheme.onSurface),
      hintStyle: t.body.copyWith(color: scheme.onSurfaceVariant),
      iconColor: scheme.onSurfaceVariant,
      sendButtonColor: scheme.primary,
      sendIconColor: scheme.onPrimary,
    );
  }

  final Color backgroundColor;
  final Color inputColor;
  final TextStyle textStyle;
  final TextStyle hintStyle;
  final Color iconColor;

  /// Send and microphone buttons.
  final Color sendButtonColor;
  final Color sendIconColor;

  /// Around the input row.
  final EdgeInsets padding;
  final double inputRadius;
  final BorderSide inputBorder;
  final EdgeInsets inputPadding;

  /// Send and microphone buttons; also the input's minimum height.
  final double buttonSize;
  final double iconSize;

  /// Line above the composer.
  final BorderSide border;

  ChatComposerStyle copyWith({
    Color? backgroundColor,
    Color? inputColor,
    TextStyle? textStyle,
    TextStyle? hintStyle,
    Color? iconColor,
    Color? sendButtonColor,
    Color? sendIconColor,
    EdgeInsets? padding,
    double? inputRadius,
    BorderSide? inputBorder,
    EdgeInsets? inputPadding,
    double? buttonSize,
    double? iconSize,
    BorderSide? border,
  }) {
    return ChatComposerStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      inputColor: inputColor ?? this.inputColor,
      textStyle: textStyle ?? this.textStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      iconColor: iconColor ?? this.iconColor,
      sendButtonColor: sendButtonColor ?? this.sendButtonColor,
      sendIconColor: sendIconColor ?? this.sendIconColor,
      padding: padding ?? this.padding,
      inputRadius: inputRadius ?? this.inputRadius,
      inputBorder: inputBorder ?? this.inputBorder,
      inputPadding: inputPadding ?? this.inputPadding,
      buttonSize: buttonSize ?? this.buttonSize,
      iconSize: iconSize ?? this.iconSize,
      border: border ?? this.border,
    );
  }

  ChatComposerStyle mapText(ChatTextMapper map) =>
      copyWith(textStyle: map(textStyle), hintStyle: map(hintStyle));

  ChatComposerStyle scaled(double factor, {double? textFactor}) {
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      padding: padding * factor,
      inputRadius: inputRadius * factor,
      inputBorder: _side(inputBorder, factor),
      inputPadding: inputPadding * factor,
      buttonSize: buttonSize * factor,
      iconSize: iconSize * factor,
      border: _side(border, factor),
    );
  }

  ChatComposerStyle lerp(ChatComposerStyle b, double t) {
    final a = this;
    return ChatComposerStyle(
      backgroundColor: _c(a.backgroundColor, b.backgroundColor, t),
      inputColor: _c(a.inputColor, b.inputColor, t),
      textStyle: _t(a.textStyle, b.textStyle, t),
      hintStyle: _t(a.hintStyle, b.hintStyle, t),
      iconColor: _c(a.iconColor, b.iconColor, t),
      sendButtonColor: _c(a.sendButtonColor, b.sendButtonColor, t),
      sendIconColor: _c(a.sendIconColor, b.sendIconColor, t),
      padding: _e(a.padding, b.padding, t),
      inputRadius: _d(a.inputRadius, b.inputRadius, t),
      inputBorder: _b(a.inputBorder, b.inputBorder, t),
      inputPadding: _e(a.inputPadding, b.inputPadding, t),
      buttonSize: _d(a.buttonSize, b.buttonSize, t),
      iconSize: _d(a.iconSize, b.iconSize, t),
      border: _b(a.border, b.border, t),
    );
  }
}

/// The room app bar heading.
@immutable
class ChatAppBarStyle {
  const ChatAppBarStyle({
    required this.titleStyle,
    required this.subtitleStyle,
    required this.typingStyle,
    this.backgroundColor,
    this.avatarSize = 40,
    this.gap = 10,
  });

  factory ChatAppBarStyle.fallback(ColorScheme scheme, {TextTheme? textTheme}) {
    final t = _Text(textTheme);
    final subtitle = t.caption.copyWith(color: scheme.onSurfaceVariant);
    return ChatAppBarStyle(
      titleStyle: t.title.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      subtitleStyle: subtitle,
      typingStyle: subtitle.copyWith(color: scheme.primary),
    );
  }

  final TextStyle titleStyle;

  /// Presence or member count.
  final TextStyle subtitleStyle;

  /// Subtitle while someone types.
  final TextStyle typingStyle;

  /// Null uses the `AppBarTheme`.
  final Color? backgroundColor;
  final double avatarSize;

  /// Between the avatar and the title.
  final double gap;

  ChatAppBarStyle copyWith({
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? typingStyle,
    Color? backgroundColor,
    double? avatarSize,
    double? gap,
  }) {
    return ChatAppBarStyle(
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      typingStyle: typingStyle ?? this.typingStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      avatarSize: avatarSize ?? this.avatarSize,
      gap: gap ?? this.gap,
    );
  }

  ChatAppBarStyle mapText(ChatTextMapper map) => copyWith(
    titleStyle: map(titleStyle),
    subtitleStyle: map(subtitleStyle),
    typingStyle: map(typingStyle),
  );

  ChatAppBarStyle scaled(double factor, {double? textFactor}) {
    return mapText(
      (s) => _font(s, textFactor ?? factor),
    ).copyWith(avatarSize: avatarSize * factor, gap: gap * factor);
  }

  ChatAppBarStyle lerp(ChatAppBarStyle b, double t) {
    final a = this;
    return ChatAppBarStyle(
      titleStyle: _t(a.titleStyle, b.titleStyle, t),
      subtitleStyle: _t(a.subtitleStyle, b.subtitleStyle, t),
      typingStyle: _t(a.typingStyle, b.typingStyle, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      avatarSize: _d(a.avatarSize, b.avatarSize, t),
      gap: _d(a.gap, b.gap, t),
    );
  }
}

/// User and room avatars.
@immutable
class ChatAvatarStyle {
  const ChatAvatarStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    this.radius,
    this.border = BorderSide.none,
    this.onlineColor = const Color(0xFF34C759),
  });

  factory ChatAvatarStyle.fallback(ColorScheme scheme) => ChatAvatarStyle(
    backgroundColor: scheme.secondaryContainer,
    foregroundColor: scheme.onSecondaryContainer,
  );

  final Color backgroundColor;

  /// Initials.
  final Color foregroundColor;

  /// Corner radius; null draws a circle.
  final double? radius;
  final BorderSide border;

  /// The presence dot.
  final Color onlineColor;

  ChatAvatarStyle copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    double? radius,
    BorderSide? border,
    Color? onlineColor,
  }) {
    return ChatAvatarStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      radius: radius ?? this.radius,
      border: border ?? this.border,
      onlineColor: onlineColor ?? this.onlineColor,
    );
  }

  ChatAvatarStyle scaled(double factor) {
    final radius = this.radius;
    return ChatAvatarStyle(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      radius: radius == null ? null : radius * factor,
      border: _side(border, factor),
      onlineColor: onlineColor,
    );
  }

  ChatAvatarStyle lerp(ChatAvatarStyle b, double t) {
    final a = this;
    return ChatAvatarStyle(
      backgroundColor: _c(a.backgroundColor, b.backgroundColor, t),
      foregroundColor: _c(a.foregroundColor, b.foregroundColor, t),
      radius: a.radius == null || b.radius == null
          ? (t < 0.5 ? a.radius : b.radius)
          : _d(a.radius!, b.radius!, t),
      border: _b(a.border, b.border, t),
      onlineColor: _c(a.onlineColor, b.onlineColor, t),
    );
  }
}

/// One inbox row. Start from a preset ([ChatRoomTileStyle.plain],
/// [ChatRoomTileStyle.divided], [ChatRoomTileStyle.card]) and adjust with
/// [copyWith]; [shape] takes any `ShapeBorder`.
@immutable
class ChatRoomTileStyle {
  const ChatRoomTileStyle({
    required this.titleStyle,
    required this.unreadTitleStyle,
    required this.subtitleStyle,
    required this.unreadSubtitleStyle,
    required this.typingStyle,
    required this.timeStyle,
    required this.unreadTimeStyle,
    required this.iconColor,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.margin = EdgeInsets.zero,
    this.shape = const RoundedRectangleBorder(),
    this.elevation = 0,
    this.divider = BorderSide.none,
    this.dividerIndent,
    this.avatarSize = 52,
    this.gap = 12,
    this.lineGap = 4,
    this.trailingGap = 8,
    this.iconSize = 16,
  });

  /// Edge to edge rows without lines.
  factory ChatRoomTileStyle.plain(ColorScheme scheme, {TextTheme? textTheme}) {
    final t = _Text(textTheme);
    final title = t.title.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final subtitle = t.medium.copyWith(color: scheme.onSurfaceVariant);
    final time = t.label.copyWith(color: scheme.onSurfaceVariant);
    return ChatRoomTileStyle(
      titleStyle: title,
      unreadTitleStyle: title.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: subtitle,
      unreadSubtitleStyle: subtitle.copyWith(color: scheme.onSurface),
      typingStyle: subtitle.copyWith(color: scheme.primary),
      timeStyle: time,
      unreadTimeStyle: time.copyWith(color: scheme.primary),
      iconColor: scheme.onSurfaceVariant,
    );
  }

  /// A line under each row only. [indent] defaults to the text start.
  factory ChatRoomTileStyle.divided(
    ColorScheme scheme, {
    TextTheme? textTheme,
    BorderSide? side,
    double? indent,
  }) {
    return ChatRoomTileStyle.plain(scheme, textTheme: textTheme).copyWith(
      divider: side ?? BorderSide(color: scheme.outlineVariant, width: 0.5),
      dividerIndent: indent,
    );
  }

  /// Separate rounded cards.
  factory ChatRoomTileStyle.card(
    ColorScheme scheme, {
    TextTheme? textTheme,
    double radius = 16,
    Color? color,
    double elevation = 0,
    BorderSide side = BorderSide.none,
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  }) {
    return ChatRoomTileStyle.plain(scheme, textTheme: textTheme).copyWith(
      color: color ?? scheme.surfaceContainerLow,
      margin: margin,
      elevation: elevation,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
    );
  }

  final TextStyle titleStyle;
  final TextStyle unreadTitleStyle;

  /// Last message preview.
  final TextStyle subtitleStyle;
  final TextStyle unreadSubtitleStyle;

  /// "Sara is typing…" in place of the preview.
  final TextStyle typingStyle;
  final TextStyle timeStyle;

  /// Time of a room with unread messages that is not muted.
  final TextStyle unreadTimeStyle;

  /// Muted, pinned and message kind icons.
  final Color iconColor;

  /// Background; null is transparent.
  final Color? color;

  /// Inside the shape.
  final EdgeInsets padding;

  /// Outside the shape, for cards.
  final EdgeInsets margin;
  final ShapeBorder shape;
  final double elevation;

  /// Line under the row; `BorderSide.none` for no line.
  final BorderSide divider;

  /// Start inset of [divider]; null lines it up with the title.
  final double? dividerIndent;
  final double avatarSize;

  /// Between the avatar and the text.
  final double gap;

  /// Between the title and the preview.
  final double lineGap;

  /// Between the text and the time / badge column.
  final double trailingGap;
  final double iconSize;

  ChatRoomTileStyle copyWith({
    TextStyle? titleStyle,
    TextStyle? unreadTitleStyle,
    TextStyle? subtitleStyle,
    TextStyle? unreadSubtitleStyle,
    TextStyle? typingStyle,
    TextStyle? timeStyle,
    TextStyle? unreadTimeStyle,
    Color? iconColor,
    Color? color,
    EdgeInsets? padding,
    EdgeInsets? margin,
    ShapeBorder? shape,
    double? elevation,
    BorderSide? divider,
    double? dividerIndent,
    double? avatarSize,
    double? gap,
    double? lineGap,
    double? trailingGap,
    double? iconSize,
  }) {
    return ChatRoomTileStyle(
      titleStyle: titleStyle ?? this.titleStyle,
      unreadTitleStyle: unreadTitleStyle ?? this.unreadTitleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      unreadSubtitleStyle: unreadSubtitleStyle ?? this.unreadSubtitleStyle,
      typingStyle: typingStyle ?? this.typingStyle,
      timeStyle: timeStyle ?? this.timeStyle,
      unreadTimeStyle: unreadTimeStyle ?? this.unreadTimeStyle,
      iconColor: iconColor ?? this.iconColor,
      color: color ?? this.color,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      shape: shape ?? this.shape,
      elevation: elevation ?? this.elevation,
      divider: divider ?? this.divider,
      dividerIndent: dividerIndent ?? this.dividerIndent,
      avatarSize: avatarSize ?? this.avatarSize,
      gap: gap ?? this.gap,
      lineGap: lineGap ?? this.lineGap,
      trailingGap: trailingGap ?? this.trailingGap,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  ChatRoomTileStyle mapText(ChatTextMapper map) => copyWith(
    titleStyle: map(titleStyle),
    unreadTitleStyle: map(unreadTitleStyle),
    subtitleStyle: map(subtitleStyle),
    unreadSubtitleStyle: map(unreadSubtitleStyle),
    typingStyle: map(typingStyle),
    timeStyle: map(timeStyle),
    unreadTimeStyle: map(unreadTimeStyle),
  );

  ChatRoomTileStyle scaled(double factor, {double? textFactor}) {
    final indent = dividerIndent;
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      padding: padding * factor,
      margin: margin * factor,
      shape: shape.scale(factor),
      elevation: elevation * factor,
      divider: _side(divider, factor),
      dividerIndent: indent == null ? null : indent * factor,
      avatarSize: avatarSize * factor,
      gap: gap * factor,
      lineGap: lineGap * factor,
      trailingGap: trailingGap * factor,
      iconSize: iconSize * factor,
    );
  }

  ChatRoomTileStyle lerp(ChatRoomTileStyle b, double t) {
    final a = this;
    final ai = a.dividerIndent;
    final bi = b.dividerIndent;
    return ChatRoomTileStyle(
      titleStyle: _t(a.titleStyle, b.titleStyle, t),
      unreadTitleStyle: _t(a.unreadTitleStyle, b.unreadTitleStyle, t),
      subtitleStyle: _t(a.subtitleStyle, b.subtitleStyle, t),
      unreadSubtitleStyle: _t(a.unreadSubtitleStyle, b.unreadSubtitleStyle, t),
      typingStyle: _t(a.typingStyle, b.typingStyle, t),
      timeStyle: _t(a.timeStyle, b.timeStyle, t),
      unreadTimeStyle: _t(a.unreadTimeStyle, b.unreadTimeStyle, t),
      iconColor: _c(a.iconColor, b.iconColor, t),
      color: Color.lerp(a.color, b.color, t),
      padding: _e(a.padding, b.padding, t),
      margin: _e(a.margin, b.margin, t),
      shape: ShapeBorder.lerp(a.shape, b.shape, t)!,
      elevation: _d(a.elevation, b.elevation, t),
      divider: _b(a.divider, b.divider, t),
      dividerIndent: ai == null || bi == null
          ? (t < 0.5 ? ai : bi)
          : _d(ai, bi, t),
      avatarSize: _d(a.avatarSize, b.avatarSize, t),
      gap: _d(a.gap, b.gap, t),
      lineGap: _d(a.lineGap, b.lineGap, t),
      trailingGap: _d(a.trailingGap, b.trailingGap, t),
      iconSize: _d(a.iconSize, b.iconSize, t),
    );
  }
}

/// Unread counters: room tiles, the scroll-to-bottom button and the
/// profile menu.
@immutable
class ChatBadgeStyle {
  const ChatBadgeStyle({
    required this.color,
    required this.mutedColor,
    required this.textStyle,
    this.size = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
    this.radius = 10,
  });

  factory ChatBadgeStyle.fallback(ColorScheme scheme, {TextTheme? textTheme}) {
    return ChatBadgeStyle(
      color: scheme.primary,
      mutedColor: scheme.onSurfaceVariant,
      textStyle: _Text(
        textTheme,
      ).small.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600),
    );
  }

  final Color color;

  /// Badge of a muted room.
  final Color mutedColor;
  final TextStyle textStyle;

  /// Height and minimum width.
  final double size;
  final EdgeInsets padding;
  final double radius;

  ChatBadgeStyle copyWith({
    Color? color,
    Color? mutedColor,
    TextStyle? textStyle,
    double? size,
    EdgeInsets? padding,
    double? radius,
  }) {
    return ChatBadgeStyle(
      color: color ?? this.color,
      mutedColor: mutedColor ?? this.mutedColor,
      textStyle: textStyle ?? this.textStyle,
      size: size ?? this.size,
      padding: padding ?? this.padding,
      radius: radius ?? this.radius,
    );
  }

  ChatBadgeStyle mapText(ChatTextMapper map) =>
      copyWith(textStyle: map(textStyle));

  ChatBadgeStyle scaled(double factor, {double? textFactor}) {
    return mapText((s) => _font(s, textFactor ?? factor)).copyWith(
      size: size * factor,
      padding: padding * factor,
      radius: radius * factor,
    );
  }

  ChatBadgeStyle lerp(ChatBadgeStyle b, double t) {
    final a = this;
    return ChatBadgeStyle(
      color: _c(a.color, b.color, t),
      mutedColor: _c(a.mutedColor, b.mutedColor, t),
      textStyle: _t(a.textStyle, b.textStyle, t),
      size: _d(a.size, b.size, t),
      padding: _e(a.padding, b.padding, t),
      radius: _d(a.radius, b.radius, t),
    );
  }
}
