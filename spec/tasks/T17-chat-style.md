# T17 — `ChatStyle`: one widget to style and scale the chat

## Goal

Styling only the chat part of an app takes one widget and nothing to remember:

1. **`ChatStyle`** wraps any chat screen or section. With no options the chat follows the app's colors and fonts (light and dark). Simple named options change common things: `preset`, `seedColor`, `bubbleRadius`, `bubbleShadows`, `bubbleBorder`, `messageStyle`, `fontFamily`, `tiles`, `tileRadius`, `squareAvatars`, `wallpaper`. `customize` gives full `ChatTheme` access. The order is fixed inside: preset, options, customize, then scale.
2. **Scale with any package.** `scale: (context) => ChatScale(1.w, text: 1.sp)` (flutter_scale_kit and screenutil), or the built-in `ChatScale.byScreen()`. `ChatStyle` depends on the screen size itself, so rotation, window resize and foldables rebuild the chat; no package-specific watch call.
3. **Nesting.** An inner `ChatStyle` only changes what it passes; the rest is inherited.
4. **Routes keep the style.** `InboxView(roomBuilder: ...)` pushes the room with the style of the inbox, and `ChatStyle.push` does the same for any page. Pushed pages follow live changes of the origin style. Sheets and dialogs already capture the theme.
5. **Presets in the package.** `ChatPreset.classic`, `whatsApp`, `telegram`, `minimal`, `cards`, and custom presets.
6. **Helpers.** `context.chatTheme`, `ChatStyle.scaleOf(context)`. A `theme:` passed to `ChatRoomView` / `InboxView` also gets the `ChatStyle` scale.

## Read first

- [T16](T16-styling-custom-messages.md), [../package.md](../package.md)

## Depends on

T16.

## Deliverables

```text
lib/src/config/chat_scale.dart          ChatScale, ChatScaler, ChatScale.fixed / byScreen
lib/src/config/chat_preset.dart         ChatPreset (+ 5 built-ins), ChatTiles
lib/src/widgets/common/chat_style.dart  ChatStyle, scope, carry / push
lib/src/config/chat_theme.dart          context.chatTheme
lib/src/widgets/inbox/inbox_view.dart   roomBuilder; onRoomTap optional
example/                                ChatStyle + package presets, flutter_scale_kit toggle
README.md, doc/customization.md         ChatStyle first; scale kit + theme kit guide; AI agent section
```

## Public API

```dart
ChatStyle(
  preset: ChatPreset.whatsApp,
  bubbleRadius: 16,
  scale: (context) => ChatScale(1.w, text: 1.sp),
  customize: (theme) => theme.copyWith(...),
  child: InboxView(
    controller: inbox,
    roomBuilder: (context, room) => RoomPage(roomId: room.id),
  ),
);

ChatStyle.push(context, (context) => RoomPage(roomId: id));
final chat = context.chatTheme; // chat.size(12), chat.fontSize(15)
```

## Done when

- [x] No options: same theme as the ambient `ChatTheme` (or fallback)
- [x] Options apply over the preset; `customize` runs after them; scale last
- [x] Nested `ChatStyle` inherits and overrides; never scales twice
- [x] Screen resize and rotation recompute the scale; an ancestor that updates a scale singleton in `didChangeDependencies` (like `ScaleKitBuilder`) is read fresh
- [x] Rooms opened by `roomBuilder` / `ChatStyle.push` keep the style and follow its changes
- [x] Example uses `ChatStyle`; real `flutter_scale_kit` test proves `chat.size(14) == 14.w` and `fontSize(14) == 14.sp`
- [x] README rewritten for Flutter developers; skill bundled in lemsa-skills

## As built

- Scale packages are linear (`14.w == 14 × 1.w`, no rounding), so one factor per axis is exact. The chat uses the width factor for all sizes and never `.h`; radii follow `.w`, not flutter_scale_kit's `.r`.
- `createResponsiveTextTheme` changes no sizes on a text theme without written font sizes (Flutter's default, flutter_scale_theme_kit's), so `text: 1.sp` is not applied twice; `example/test/scale_kit_test.dart` covers it.
- Carried pages listen to a `ValueNotifier` owned by the origin `ChatStyle` and updated after the frame; it is never disposed, so a page keeps the last style after the origin is gone.

## Do not

- Add a scale package to the package `pubspec.yaml` (example only).
- Replace `ChatTheme` / `ThemeData.extensions`; `ChatStyle` is the easy way in, not a second theme system.
