# T12 — App bar, ChatRoomView, InboxView

## Goal

Ready-to-use pages assembled from the pieces, plus the chat app bar with app-supplied actions. Every piece stays exported so apps can compose their own page instead.

## Read first

- valizex `contact_chat_app_bar.dart`, `pages/conversations_page.dart`
- lightnessword `screens/conversation_screen.dart`, `widgets/conversation_card_widget.dart`

## Depends on

T11.

## Deliverables

```text
lib/src/widgets/room/chat_app_bar.dart     ChatAppBar, ChatAppBarOptions
lib/src/widgets/room/chat_room_view.dart   ChatRoomView
lib/src/widgets/room/selection_app_bar.dart  shown in multi-select (copy, delete, forward callback)
lib/src/widgets/inbox/inbox_view.dart      InboxView
lib/src/widgets/inbox/room_tile.dart       RoomTile
lib/src/widgets/inbox/inbox_search_bar.dart
test/widgets/views_test.dart
```

## Public API

```dart
class ChatAppBarOptions {
  const ChatAppBarOptions({this.actions = const [], this.titleBuilder, this.subtitleBuilder,
    this.leadingBuilder, this.onTitleTap, this.backgroundColor, this.showBack = true});
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  // title: room title or other user's name; avatar (stacked avatars for groups)
  // subtitle: "Ana is typing…" > "online" / last seen > member count for groups
}

class ChatRoomView extends StatefulWidget {
  const ChatRoomView({
    required this.controller, this.composer, this.appBar = const ChatAppBarOptions(), this.appBarBuilder,
    this.builders = const ChatBuilders(), this.theme, this.config, this.strings, this.formatters,
    this.header,              // e.g. pinned banner (valizex pending transaction bar)
    this.onMessageTap, this.onAvatarTap, this.onLinkTap, this.onAttachmentPick,
    this.extraAttachmentOptions = const [], this.background,
  });
}

class InboxView extends StatefulWidget {
  const InboxView({
    required this.controller, required this.onRoomTap, this.builders = const InboxBuilders(),
    this.showSearch = true, this.header, this.theme, this.strings, this.formatters,
  });
}
```

`RoomTile`: avatar (+ online dot), title, last message preview (type-aware: "📷 Photo", "🎤 0:12", custom via `strings`/builder, "You: " prefix), time, unread badge, muted icon, pinned icon, typing preview.

## Done when

- [x] Widget tests: app-supplied `actions` render in the app bar; typing subtitle replaces online; group subtitle shows member count; `header` renders; inbox search filters; tile shows unread badge and muted icon; tap calls `onRoomTap`; pagination on scroll end
- [x] `ChatRoomView` creates its own `ComposerController` when none is passed and disposes it

## As built

- **`ChatAppBar`.** Takes `controller`, `options`, `strings` and `formatters`. The name comes from `roomDisplayName` (room title, else the peer's name, else the other members' names). `leadingBuilder` wraps the avatar; the back button (tooltip `strings.back`) shows only when the route can pop and `showBack` is true. Presence comes from `ChatRepository.watchPresence`, which only receives events while an inbox is open.
- **`ChatRoomView`.** On top of the API above it takes `appBarBuilder` (return null to hide the bar), `composerBuilder`, `onAttachmentTap`, `onForward` and `backgroundColor`. `theme` applies a `ChatTheme` to this screen only. While messages are selected it shows `SelectionAppBar`, and system back clears the selection instead of popping. It wires the list's reply and edit to the composer and turns on `ChatMessageList.enableSelection`.
- **Selection.** The long-press sheet gains a "Select" action (`MessageAction.selectId`), shown only when `ChatMessageList.enableSelection` is true. `SelectionAppBar` copies all selected texts, forwards (only with `onForward`, and only confirmed messages) and deletes (only when every selected message is the user's; pending ones are discarded). The sheet now scrolls when its actions do not fit.
- **`InboxView`.** Adds `onRoomLongPress` and `loadMoreThreshold`. The next page loads near the end of the scroll, and also after a frame when the rooms do not fill the screen (skipped after a failure, so it never retries in a loop). Pull to refresh; loading, error (`loadChatsFailed`), empty (`noChats`) and no-results (`noResults`) states each go through their builder.
- **Swipe actions.** `RoomSwipeActions` reveals pin and mute (edited through `InboxBuilders.swipeActions`) at the trailing edge, RTL aware. The same actions show in a sheet on long press and as accessibility actions.
- **`RoomTile`.** Type icons (photo, video, mic, file, deleted) instead of emoji; a voice note shows its duration. `RoomTile.previewOf` adds the `previewWithAuthor` prefix for my messages ("You") and for group authors. The badge shows "99+" above 99 and is announced through `strings.unreadCount`.
- **Typing in the inbox.** `ChatRepository.typingChanges` streams typing for every room; `InboxController.typingNames(room)` resolves the names.
- **Shared pieces.** `RoomAvatar` (stacked member avatars for a group without an image, online dot) and `roomDisplayName`.
- **Strings (D12).** New `ChatStrings` entries: `back`, `forward`, `select`, `pin`, `unpin`, `mute`, `unmute`, `clearSearch`, `noResults`, `loadChatsFailed`, and the functions `members`, `selectedCount`, `previewWithAuthor`, `unreadCount`.

## Do not

- Navigate inside the kit (callbacks only)
- Hide composable pieces behind the views (all stay exported)
