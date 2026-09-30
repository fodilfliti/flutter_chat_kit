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

- [ ] Widget tests: app-supplied `actions` render in the app bar; typing subtitle replaces online; group subtitle shows member count; `header` renders; inbox search filters; tile shows unread badge and muted icon; tap calls `onRoomTap`; pagination on scroll end
- [ ] `ChatRoomView` creates its own `ComposerController` when none is passed and disposes it

## Do not

- Navigate inside the kit (callbacks only)
- Hide composable pieces behind the views (all stay exported)
