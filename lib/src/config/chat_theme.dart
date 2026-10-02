import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_styles.dart';

/// Visual settings for the chat room and inbox, one style per part.
///
/// Every size, color, text style, border and shadow the default widgets
/// draw comes from here. The easy way to set it is the `ChatStyle` widget
/// (presets, simple options, screen scale). It can also be registered on
/// `ThemeData.extensions`, usually derived from the app's color scheme so
/// light and dark themes animate between each other:
///
/// ```dart
/// final chat = ChatTheme.fallback(scheme);
/// ThemeData(
///   colorScheme: scheme,
///   extensions: [
///     chat
///         .withMessageText(const TextStyle(fontSize: 14))
///         .copyWith(roomTile: ChatRoomTileStyle.card(scheme, radius: 20))
///         .mapBubbles((bubble) => bubble.copyWith(radius: 8))
///         .scaled(1.1),
///   ],
/// )
/// ```
///
/// Apply [scaled] last: it multiplies the values set before it. Widgets
/// read the theme in `build`, so rebuilding `ThemeData` with a new scale
/// (from a scale package or a zoom setting) refreshes the whole chat.
///
/// Without an extension, [ChatTheme.of] derives one from the ambient
/// [ColorScheme] and [TextTheme].
@immutable
class ChatTheme extends ThemeExtension<ChatTheme> {
  const ChatTheme({
    required this.outgoingBubble,
    required this.incomingBubble,
    required this.messageList,
    required this.status,
    required this.dateSeparator,
    required this.systemMessage,
    required this.unreadDivider,
    required this.reactions,
    required this.replyPreview,
    required this.composer,
    required this.appBar,
    required this.avatar,
    required this.roomTile,
    required this.badge,
    required this.iconColor,
    required this.captionStyle,
    this.media = const ChatMediaStyle(),
    this.scale = 1,
    this.textScale = 1,
  });

  /// Defaults derived from [scheme] (and [textTheme] when given).
  factory ChatTheme.fallback(ColorScheme scheme, {TextTheme? textTheme}) {
    final text = textTheme ?? Typography.material2021().englishLike;
    return ChatTheme(
      outgoingBubble: ChatBubbleStyle.outgoing(scheme, textTheme: text),
      incomingBubble: ChatBubbleStyle.incoming(scheme, textTheme: text),
      messageList: ChatMessageListStyle.fallback(scheme, textTheme: text),
      status: ChatStatusStyle.fallback(scheme),
      dateSeparator: ChatChipStyle.dateSeparator(scheme, textTheme: text),
      systemMessage: ChatChipStyle.systemMessage(scheme, textTheme: text),
      unreadDivider: ChatChipStyle.unreadDivider(scheme, textTheme: text),
      reactions: ChatReactionStyle.fallback(scheme, textTheme: text),
      replyPreview: ChatReplyStyle.fallback(scheme),
      composer: ChatComposerStyle.fallback(scheme, textTheme: text),
      appBar: ChatAppBarStyle.fallback(scheme, textTheme: text),
      avatar: ChatAvatarStyle.fallback(scheme),
      roomTile: ChatRoomTileStyle.plain(scheme, textTheme: text),
      badge: ChatBadgeStyle.fallback(scheme, textTheme: text),
      iconColor: scheme.onSurfaceVariant,
      captionStyle: (text.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  /// The registered extension, or [ChatTheme.fallback] for the ambient
  /// theme.
  factory ChatTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ChatTheme>() ??
        ChatTheme.fallback(theme.colorScheme, textTheme: theme.textTheme);
  }

  /// The current user's bubbles.
  final ChatBubbleStyle outgoingBubble;
  final ChatBubbleStyle incomingBubble;
  final ChatMessageListStyle messageList;
  final ChatStatusStyle status;
  final ChatChipStyle dateSeparator;
  final ChatChipStyle systemMessage;

  /// The "New messages" line.
  final ChatChipStyle unreadDivider;
  final ChatReactionStyle reactions;
  final ChatReplyStyle replyPreview;
  final ChatMediaStyle media;
  final ChatComposerStyle composer;
  final ChatAppBarStyle appBar;
  final ChatAvatarStyle avatar;
  final ChatRoomTileStyle roomTile;
  final ChatBadgeStyle badge;

  /// Secondary icons outside the composer (swipe reply, actions, placeholders).
  final Color iconColor;

  /// Secondary text: empty and error states, sheet labels, file sizes.
  final TextStyle captionStyle;

  /// Product of every [scaled] factor applied so far.
  final double scale;

  /// Product of every [scaled] text factor applied so far.
  final double textScale;

  /// The bubble style of the current user's ([isMine]) or others' messages.
  ChatBubbleStyle bubble({required bool isMine}) =>
      isMine ? outgoingBubble : incomingBubble;

  /// [value] logical pixels at this theme's [scale], for sizes of custom
  /// widgets that should follow the chat's scale.
  double size(double value) => value * scale;

  /// [value] font size at this theme's [textScale].
  double fontSize(double value) => value * textScale;

  /// Multiplies every size, radius, padding, border and shadow by [factor],
  /// and every font size by [textFactor] (default [factor]).
  ///
  /// `ChatStyle(scale: ...)` calls this for you; use it directly only on a
  /// theme you build yourself, and last.
  ChatTheme scaled(double factor, {double? textFactor}) {
    final text = textFactor ?? factor;
    return ChatTheme(
      outgoingBubble: outgoingBubble.scaled(factor, textFactor: text),
      incomingBubble: incomingBubble.scaled(factor, textFactor: text),
      messageList: messageList.scaled(factor, textFactor: text),
      status: status.scaled(factor),
      dateSeparator: dateSeparator.scaled(factor, textFactor: text),
      systemMessage: systemMessage.scaled(factor, textFactor: text),
      unreadDivider: unreadDivider.scaled(factor, textFactor: text),
      reactions: reactions.scaled(factor, textFactor: text),
      replyPreview: replyPreview.scaled(factor),
      media: media.scaled(factor),
      composer: composer.scaled(factor, textFactor: text),
      appBar: appBar.scaled(factor, textFactor: text),
      avatar: avatar.scaled(factor),
      roomTile: roomTile.scaled(factor, textFactor: text),
      badge: badge.scaled(factor, textFactor: text),
      iconColor: iconColor,
      captionStyle: _scaleFont(captionStyle, text),
      scale: scale * factor,
      textScale: textScale * text,
    );
  }

  /// Rewrites every text style, for example to set a font family:
  /// `theme.mapText((s) => s.copyWith(fontFamily: 'Cairo'))`.
  ChatTheme mapText(ChatTextMapper map) {
    return copyWith(
      outgoingBubble: outgoingBubble.mapText(map),
      incomingBubble: incomingBubble.mapText(map),
      messageList: messageList.mapText(map),
      dateSeparator: dateSeparator.mapText(map),
      systemMessage: systemMessage.mapText(map),
      unreadDivider: unreadDivider.mapText(map),
      reactions: reactions.mapText(map),
      composer: composer.mapText(map),
      appBar: appBar.mapText(map),
      roomTile: roomTile.mapText(map),
      badge: badge.mapText(map),
      captionStyle: map(captionStyle),
    );
  }

  /// Applies [update] to both bubble styles.
  ChatTheme mapBubbles(ChatBubbleStyle Function(ChatBubbleStyle) update) =>
      copyWith(
        outgoingBubble: update(outgoingBubble),
        incomingBubble: update(incomingBubble),
      );

  /// Merges [style] into the message text of both bubbles, for example
  /// `TextStyle(fontSize: 14, color: Colors.grey)`.
  ChatTheme withMessageText(TextStyle style) => mapBubbles(
    (bubble) => bubble.copyWith(textStyle: bubble.textStyle.merge(style)),
  );

  @override
  ChatTheme copyWith({
    ChatBubbleStyle? outgoingBubble,
    ChatBubbleStyle? incomingBubble,
    ChatMessageListStyle? messageList,
    ChatStatusStyle? status,
    ChatChipStyle? dateSeparator,
    ChatChipStyle? systemMessage,
    ChatChipStyle? unreadDivider,
    ChatReactionStyle? reactions,
    ChatReplyStyle? replyPreview,
    ChatMediaStyle? media,
    ChatComposerStyle? composer,
    ChatAppBarStyle? appBar,
    ChatAvatarStyle? avatar,
    ChatRoomTileStyle? roomTile,
    ChatBadgeStyle? badge,
    Color? iconColor,
    TextStyle? captionStyle,
  }) {
    return ChatTheme(
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      messageList: messageList ?? this.messageList,
      status: status ?? this.status,
      dateSeparator: dateSeparator ?? this.dateSeparator,
      systemMessage: systemMessage ?? this.systemMessage,
      unreadDivider: unreadDivider ?? this.unreadDivider,
      reactions: reactions ?? this.reactions,
      replyPreview: replyPreview ?? this.replyPreview,
      media: media ?? this.media,
      composer: composer ?? this.composer,
      appBar: appBar ?? this.appBar,
      avatar: avatar ?? this.avatar,
      roomTile: roomTile ?? this.roomTile,
      badge: badge ?? this.badge,
      iconColor: iconColor ?? this.iconColor,
      captionStyle: captionStyle ?? this.captionStyle,
      scale: scale,
      textScale: textScale,
    );
  }

  @override
  ChatTheme lerp(covariant ThemeExtension<ChatTheme>? other, double t) {
    if (other is! ChatTheme) return this;
    return ChatTheme(
      outgoingBubble: outgoingBubble.lerp(other.outgoingBubble, t),
      incomingBubble: incomingBubble.lerp(other.incomingBubble, t),
      messageList: messageList.lerp(other.messageList, t),
      status: status.lerp(other.status, t),
      dateSeparator: dateSeparator.lerp(other.dateSeparator, t),
      systemMessage: systemMessage.lerp(other.systemMessage, t),
      unreadDivider: unreadDivider.lerp(other.unreadDivider, t),
      reactions: reactions.lerp(other.reactions, t),
      replyPreview: replyPreview.lerp(other.replyPreview, t),
      media: media.lerp(other.media, t),
      composer: composer.lerp(other.composer, t),
      appBar: appBar.lerp(other.appBar, t),
      avatar: avatar.lerp(other.avatar, t),
      roomTile: roomTile.lerp(other.roomTile, t),
      badge: badge.lerp(other.badge, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      captionStyle: lerpChatText(captionStyle, other.captionStyle, t),
      scale: lerpDouble(scale, other.scale, t)!,
      textScale: lerpDouble(textScale, other.textScale, t)!,
    );
  }

  static TextStyle _scaleFont(TextStyle style, double factor) {
    final size = style.fontSize;
    return size == null ? style : style.copyWith(fontSize: size * factor);
  }
}

/// `context.chatTheme` for custom chat widgets:
/// `Padding(padding: EdgeInsets.all(context.chatTheme.size(12)))`.
extension ChatThemeContext on BuildContext {
  /// Same as [ChatTheme.of].
  ChatTheme get chatTheme => ChatTheme.of(this);
}
