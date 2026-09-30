# T16 — Full styling, scale, and flexible custom messages

## Goal

Apps change any part of the chat UI from one place, and try several looks live:

1. **Grouped theme.** `ChatTheme` is made of one style class per part (bubbles, message list, reactions, reply preview, chips, media, composer, app bar, avatars, room tile, badges). Every size, color, text style, border and shadow a default widget draws comes from it; no hidden constants.
2. **Scale.** `ChatTheme.scaled(factor, textFactor:)` multiplies every size and font, so a scale package (`flutter_screenutil`) or an in-app zoom only rebuilds the theme. Widgets read the theme in `build`, so a new theme refreshes everything.
3. **Room tile shapes.** Plain, divided (bottom line only) or card (any `ShapeBorder`, radius, margin, elevation), each fully adjustable.
4. **Flexible custom messages.** Many custom types per project and many variants of one type: a fallback resolver (`ChatBuilders.customBuilder`) and custom cards inside the default bubble with time and ticks (`bubbledCustomTypes`).
5. **Example style lab.** A sheet in the example switches presets and adjusts font size, text color, scale, bubble radius, tile layout and more, live over the running app. The example shows three offer variants and a booking card.

## Read first

- [../package.md](../package.md), [T07](T07-theme-config-builders.md), [T09](T09-message-widgets.md), [T12](T12-views.md)

## Depends on

T15.

## Deliverables

```text
lib/src/config/chat_styles.dart     ChatBubbleStyle, ChatMessageListStyle, ChatStatusStyle, ChatChipStyle, ChatReactionStyle,
                                    ChatReplyStyle, ChatMediaStyle, ChatComposerStyle, ChatAppBarStyle, ChatAvatarStyle,
                                    ChatRoomTileStyle (plain / divided / card), ChatBadgeStyle
lib/src/config/chat_theme.dart      ChatTheme of the groups; scaled, mapText, mapBubbles, withMessageText, size, fontSize
lib/src/widgets/**                  read every size from the theme (scale applies everywhere)
lib/src/builders/chat_builders.dart customBuilder resolver, bubbledCustomTypes
example/lib/style/                  StyleSettings + presets + live style sheet
example/lib/custom/                 product offer, service quote, booking (in bubble)
doc/customization.md                theming cookbook: grouped styles, scale + screenutil, tile shapes, custom variants
```

## Public API

```dart
final base = ChatTheme.fallback(scheme);
ThemeData(
  colorScheme: scheme,
  extensions: [
    base
        .withMessageText(const TextStyle(fontSize: 14, color: Colors.grey))
        .copyWith(roomTile: ChatRoomTileStyle.card(scheme, radius: 16))
        .mapBubbles((b) => b.copyWith(radius: 8))
        .scaled(1.1),
  ],
);

ChatBuilders(
  customBuilders: {'booking': bookingCard},
  customBuilder: (context, message) => switch (variantOf(message)) {
    'quote' => QuoteCard(message: message),
    _ => null, // unsupported view
  },
  bubbledCustomTypes: {'booking'},
);
```

## Done when

- [x] No size constant left in the default widgets that ignores the theme scale
- [x] `scaled` multiplies sizes, radii, paddings, borders, shadows and fonts; lerp animates between themes
- [x] Room tile renders plain, divided and card styles; the divider indent follows the text by default
- [x] Custom resolver and bubbled custom messages render with time and ticks
- [x] Example style sheet switches presets and controls live; offer variants and a booking card
- [x] Docs compile-checked; analyze and tests green (package and example)

## As built

- Style classes use instance `lerp(other, t)` (the lint forbids static ones). `TextStyle` lerps switch halfway when `inherit` differs, so a plain `TextStyle(...)` override never breaks a theme animation.
- `ChatMessageListStyle.background` (a `Decoration`) paints behind the messages of `ChatRoomView`; the view's `background` widget still wins.
- Breaking (unpublished): the flat `ChatTheme` fields are gone; `DatePill` takes a `ChatChipStyle` instead of the theme. `ChatAvatar` draws its own clipped box (circle or `ChatAvatarStyle.radius`). Optional size params (`RoomTile.avatarSize`, `StatusTicks.size`, `VoiceRecordButton.size`, `RoomSwipeActions.actionWidth`, media `maxWidth`, ...) default to the theme.
- New public widgets: `ChatUnreadBadge`, `ChatChip`.
- Left unscaled on purpose: the full-screen media viewer and loading spinners.
- Example: presets Classic, WhatsApp-like (wallpaper, flat tails, blue seen ticks), Telegram-like (gradient bubbles and background), Minimal grey (bordered, grey text, square avatars, lined rows), Cards. Two `offer` variants (product, quote) through the resolver, plus `booking` in `bubbledCustomTypes`, seeded in "Weekend trip" and "Lemsa Shop".
- Tests: `chat_theme_test` (groups, `withMessageText`, `mapText`, `mapBubbles`, `scaled`, tile presets, lerp), `room_tile_style_test` (plain, divided, card, scale), resolver and bubbled cases in `message_widgets_test`, and the style sheet plus custom cards in the example test.

## Do not

- Add a scale package dependency to the package (the app passes the factor).
- Keep the old flat `ChatTheme` fields (0.1.0 is unpublished; one clear API).
