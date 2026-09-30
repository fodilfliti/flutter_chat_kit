import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Visual settings for the chat room and inbox.
///
/// Register it on `ThemeData.extensions`, usually derived from the app's
/// color scheme so light and dark themes animate between each other:
///
/// ```dart
/// ThemeData(
///   colorScheme: scheme,
///   extensions: [
///     ChatTheme.fallback(scheme).copyWith(bubbleRadius: 12),
///   ],
/// )
/// ```
///
/// Without an extension, [ChatTheme.of] derives one from the ambient
/// [ColorScheme] and [TextTheme].
@immutable
class ChatTheme extends ThemeExtension<ChatTheme> {
  const ChatTheme({
    required this.outgoingBubbleColor,
    required this.incomingBubbleColor,
    required this.outgoingTextStyle,
    required this.incomingTextStyle,
    required this.outgoingMetaStyle,
    required this.incomingMetaStyle,
    required this.authorNameStyle,
    required this.systemMessageStyle,
    required this.dateSeparatorStyle,
    required this.dateSeparatorColor,
    required this.highlightColor,
    required this.selectedColor,
    required this.statusColor,
    required this.seenColor,
    required this.failedColor,
    required this.replyAccentColor,
    required this.reactionColor,
    required this.reactionMineColor,
    required this.avatarBackgroundColor,
    required this.composerBackgroundColor,
    required this.composerInputColor,
    required this.composerTextStyle,
    required this.composerHintStyle,
    required this.iconColor,
    required this.sendButtonColor,
    required this.unreadBadgeColor,
    required this.unreadBadgeTextStyle,
    required this.roomTitleStyle,
    required this.roomSubtitleStyle,
    required this.roomTimeStyle,
    this.bubbleRadius = 18,
    this.tailRadius = 4,
    this.bubblePadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.listPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.maxBubbleWidthFactor = 0.78,
    this.avatarSize = 32,
    this.messageSpacing = 2,
    this.groupSpacing = 10,
  });

  /// Defaults derived from [scheme] (and [textTheme] when given).
  factory ChatTheme.fallback(ColorScheme scheme, {TextTheme? textTheme}) {
    final text = textTheme ?? Typography.material2021().englishLike;
    final body = text.bodyLarge ?? const TextStyle(fontSize: 16);
    final small = text.labelSmall ?? const TextStyle(fontSize: 11);
    final label = text.labelMedium ?? const TextStyle(fontSize: 12);
    return ChatTheme(
      outgoingBubbleColor: scheme.primary,
      incomingBubbleColor: scheme.surfaceContainerHighest,
      outgoingTextStyle: body.copyWith(color: scheme.onPrimary),
      incomingTextStyle: body.copyWith(color: scheme.onSurface),
      outgoingMetaStyle: small.copyWith(
        color: scheme.onPrimary.withValues(alpha: 0.72),
      ),
      incomingMetaStyle: small.copyWith(color: scheme.onSurfaceVariant),
      authorNameStyle: label.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      systemMessageStyle: label.copyWith(color: scheme.onSurfaceVariant),
      dateSeparatorStyle: label.copyWith(color: scheme.onSurfaceVariant),
      dateSeparatorColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.primary.withValues(alpha: 0.16),
      selectedColor: scheme.primary.withValues(alpha: 0.10),
      statusColor: scheme.onSurfaceVariant,
      seenColor: scheme.tertiary,
      failedColor: scheme.error,
      replyAccentColor: scheme.secondary,
      reactionColor: scheme.surfaceContainerHigh,
      reactionMineColor: scheme.primaryContainer,
      avatarBackgroundColor: scheme.secondaryContainer,
      composerBackgroundColor: scheme.surface,
      composerInputColor: scheme.surfaceContainerHigh,
      composerTextStyle: body.copyWith(color: scheme.onSurface),
      composerHintStyle: body.copyWith(color: scheme.onSurfaceVariant),
      iconColor: scheme.onSurfaceVariant,
      sendButtonColor: scheme.primary,
      unreadBadgeColor: scheme.primary,
      unreadBadgeTextStyle: small.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
      ),
      roomTitleStyle: (text.titleMedium ?? body).copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      roomSubtitleStyle: (text.bodyMedium ?? body).copyWith(
        color: scheme.onSurfaceVariant,
      ),
      roomTimeStyle: label.copyWith(color: scheme.onSurfaceVariant),
    );
  }

  /// The registered extension, or [ChatTheme.fallback] for the ambient
  /// theme.
  factory ChatTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ChatTheme>() ??
        ChatTheme.fallback(theme.colorScheme, textTheme: theme.textTheme);
  }

  final Color outgoingBubbleColor;
  final Color incomingBubbleColor;
  final TextStyle outgoingTextStyle;
  final TextStyle incomingTextStyle;

  /// Timestamp and "edited" label inside outgoing bubbles.
  final TextStyle outgoingMetaStyle;
  final TextStyle incomingMetaStyle;
  final TextStyle authorNameStyle;
  final TextStyle systemMessageStyle;
  final TextStyle dateSeparatorStyle;
  final Color dateSeparatorColor;

  /// Flash behind a message reached by jump-to-message.
  final Color highlightColor;
  final Color selectedColor;

  /// Pending, sent and delivered ticks.
  final Color statusColor;
  final Color seenColor;
  final Color failedColor;
  final Color replyAccentColor;
  final Color reactionColor;
  final Color reactionMineColor;
  final Color avatarBackgroundColor;
  final Color composerBackgroundColor;
  final Color composerInputColor;
  final TextStyle composerTextStyle;
  final TextStyle composerHintStyle;
  final Color iconColor;
  final Color sendButtonColor;
  final Color unreadBadgeColor;
  final TextStyle unreadBadgeTextStyle;
  final TextStyle roomTitleStyle;
  final TextStyle roomSubtitleStyle;
  final TextStyle roomTimeStyle;
  final double bubbleRadius;

  /// Corner radius on the author side of grouped bubbles.
  final double tailRadius;
  final EdgeInsets bubblePadding;
  final EdgeInsets listPadding;

  /// Bubble width as a fraction of the list width.
  final double maxBubbleWidthFactor;
  final double avatarSize;

  /// Gap between messages of one group.
  final double messageSpacing;

  /// Gap between groups.
  final double groupSpacing;

  @override
  ChatTheme copyWith({
    Color? outgoingBubbleColor,
    Color? incomingBubbleColor,
    TextStyle? outgoingTextStyle,
    TextStyle? incomingTextStyle,
    TextStyle? outgoingMetaStyle,
    TextStyle? incomingMetaStyle,
    TextStyle? authorNameStyle,
    TextStyle? systemMessageStyle,
    TextStyle? dateSeparatorStyle,
    Color? dateSeparatorColor,
    Color? highlightColor,
    Color? selectedColor,
    Color? statusColor,
    Color? seenColor,
    Color? failedColor,
    Color? replyAccentColor,
    Color? reactionColor,
    Color? reactionMineColor,
    Color? avatarBackgroundColor,
    Color? composerBackgroundColor,
    Color? composerInputColor,
    TextStyle? composerTextStyle,
    TextStyle? composerHintStyle,
    Color? iconColor,
    Color? sendButtonColor,
    Color? unreadBadgeColor,
    TextStyle? unreadBadgeTextStyle,
    TextStyle? roomTitleStyle,
    TextStyle? roomSubtitleStyle,
    TextStyle? roomTimeStyle,
    double? bubbleRadius,
    double? tailRadius,
    EdgeInsets? bubblePadding,
    EdgeInsets? listPadding,
    double? maxBubbleWidthFactor,
    double? avatarSize,
    double? messageSpacing,
    double? groupSpacing,
  }) {
    return ChatTheme(
      outgoingBubbleColor: outgoingBubbleColor ?? this.outgoingBubbleColor,
      incomingBubbleColor: incomingBubbleColor ?? this.incomingBubbleColor,
      outgoingTextStyle: outgoingTextStyle ?? this.outgoingTextStyle,
      incomingTextStyle: incomingTextStyle ?? this.incomingTextStyle,
      outgoingMetaStyle: outgoingMetaStyle ?? this.outgoingMetaStyle,
      incomingMetaStyle: incomingMetaStyle ?? this.incomingMetaStyle,
      authorNameStyle: authorNameStyle ?? this.authorNameStyle,
      systemMessageStyle: systemMessageStyle ?? this.systemMessageStyle,
      dateSeparatorStyle: dateSeparatorStyle ?? this.dateSeparatorStyle,
      dateSeparatorColor: dateSeparatorColor ?? this.dateSeparatorColor,
      highlightColor: highlightColor ?? this.highlightColor,
      selectedColor: selectedColor ?? this.selectedColor,
      statusColor: statusColor ?? this.statusColor,
      seenColor: seenColor ?? this.seenColor,
      failedColor: failedColor ?? this.failedColor,
      replyAccentColor: replyAccentColor ?? this.replyAccentColor,
      reactionColor: reactionColor ?? this.reactionColor,
      reactionMineColor: reactionMineColor ?? this.reactionMineColor,
      avatarBackgroundColor:
          avatarBackgroundColor ?? this.avatarBackgroundColor,
      composerBackgroundColor:
          composerBackgroundColor ?? this.composerBackgroundColor,
      composerInputColor: composerInputColor ?? this.composerInputColor,
      composerTextStyle: composerTextStyle ?? this.composerTextStyle,
      composerHintStyle: composerHintStyle ?? this.composerHintStyle,
      iconColor: iconColor ?? this.iconColor,
      sendButtonColor: sendButtonColor ?? this.sendButtonColor,
      unreadBadgeColor: unreadBadgeColor ?? this.unreadBadgeColor,
      unreadBadgeTextStyle: unreadBadgeTextStyle ?? this.unreadBadgeTextStyle,
      roomTitleStyle: roomTitleStyle ?? this.roomTitleStyle,
      roomSubtitleStyle: roomSubtitleStyle ?? this.roomSubtitleStyle,
      roomTimeStyle: roomTimeStyle ?? this.roomTimeStyle,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      tailRadius: tailRadius ?? this.tailRadius,
      bubblePadding: bubblePadding ?? this.bubblePadding,
      listPadding: listPadding ?? this.listPadding,
      maxBubbleWidthFactor: maxBubbleWidthFactor ?? this.maxBubbleWidthFactor,
      avatarSize: avatarSize ?? this.avatarSize,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      groupSpacing: groupSpacing ?? this.groupSpacing,
    );
  }

  @override
  ChatTheme lerp(covariant ThemeExtension<ChatTheme>? other, double t) {
    if (other is! ChatTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    EdgeInsets e(EdgeInsets a, EdgeInsets b) => EdgeInsets.lerp(a, b, t)!;
    return ChatTheme(
      outgoingBubbleColor: c(outgoingBubbleColor, other.outgoingBubbleColor),
      incomingBubbleColor: c(incomingBubbleColor, other.incomingBubbleColor),
      outgoingTextStyle: s(outgoingTextStyle, other.outgoingTextStyle),
      incomingTextStyle: s(incomingTextStyle, other.incomingTextStyle),
      outgoingMetaStyle: s(outgoingMetaStyle, other.outgoingMetaStyle),
      incomingMetaStyle: s(incomingMetaStyle, other.incomingMetaStyle),
      authorNameStyle: s(authorNameStyle, other.authorNameStyle),
      systemMessageStyle: s(systemMessageStyle, other.systemMessageStyle),
      dateSeparatorStyle: s(dateSeparatorStyle, other.dateSeparatorStyle),
      dateSeparatorColor: c(dateSeparatorColor, other.dateSeparatorColor),
      highlightColor: c(highlightColor, other.highlightColor),
      selectedColor: c(selectedColor, other.selectedColor),
      statusColor: c(statusColor, other.statusColor),
      seenColor: c(seenColor, other.seenColor),
      failedColor: c(failedColor, other.failedColor),
      replyAccentColor: c(replyAccentColor, other.replyAccentColor),
      reactionColor: c(reactionColor, other.reactionColor),
      reactionMineColor: c(reactionMineColor, other.reactionMineColor),
      avatarBackgroundColor: c(
        avatarBackgroundColor,
        other.avatarBackgroundColor,
      ),
      composerBackgroundColor: c(
        composerBackgroundColor,
        other.composerBackgroundColor,
      ),
      composerInputColor: c(composerInputColor, other.composerInputColor),
      composerTextStyle: s(composerTextStyle, other.composerTextStyle),
      composerHintStyle: s(composerHintStyle, other.composerHintStyle),
      iconColor: c(iconColor, other.iconColor),
      sendButtonColor: c(sendButtonColor, other.sendButtonColor),
      unreadBadgeColor: c(unreadBadgeColor, other.unreadBadgeColor),
      unreadBadgeTextStyle: s(unreadBadgeTextStyle, other.unreadBadgeTextStyle),
      roomTitleStyle: s(roomTitleStyle, other.roomTitleStyle),
      roomSubtitleStyle: s(roomSubtitleStyle, other.roomSubtitleStyle),
      roomTimeStyle: s(roomTimeStyle, other.roomTimeStyle),
      bubbleRadius: d(bubbleRadius, other.bubbleRadius),
      tailRadius: d(tailRadius, other.tailRadius),
      bubblePadding: e(bubblePadding, other.bubblePadding),
      listPadding: e(listPadding, other.listPadding),
      maxBubbleWidthFactor: d(maxBubbleWidthFactor, other.maxBubbleWidthFactor),
      avatarSize: d(avatarSize, other.avatarSize),
      messageSpacing: d(messageSpacing, other.messageSpacing),
      groupSpacing: d(groupSpacing, other.groupSpacing),
    );
  }
}
