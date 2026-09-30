---
name: flutter-chat-kit
description: >
  Use flutter_chat_kit to build chat screens: a chat room page, an inbox
  (conversation list), direct and group chats, media and voice messages,
  replies, reactions, read receipts, offline cache and outbox. Activate when
  implementing a ChatSource for Firebase, Supabase or REST, customizing message
  bubbles, adding custom message types (offers, cards), or adding app bar
  actions to a chat page — not for backend SDK code inside the kit, Riverpod
  inside the kit, or localizing inside the kit.
license: MIT
metadata:
  author: fodilfliti
  version: "0.1.0"
  homepage: https://pub.dev/packages/flutter_chat_kit
---

# flutter_chat_kit (consumer)

## Import

```dart
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart'; // AppFailure, Change
```

Use this package for:

- A chat room page and an inbox that work offline (built-in SQLite cache,
  one database per user, persistent outbox).
- Any backend: the app implements `ChatSource`, `ChatUploader` and
  `ChatUserResolver`.
- Custom message types through `CustomMessage` + `ChatBuilders.customBuilders`.
- Replacing any piece of the UI (bubble, app bar, composer, tiles) through
  builders that receive the default widget.

## Architecture

| Piece | Owner | Notes |
| --- | --- | --- |
| `ChatSource` | app | fetch pages, realtime `events`, send / edit / delete / markRead; or `ComposedChatSource(data:, realtime:)` |
| `ChatUploader` | app | uploads a file, streams `UploadRunning` then one `UploadDone` |
| `ChatUserResolver` | app | `resolve(Set<String> ids)` → names and avatars; kit batches and caches |
| `ChatKit` | kit | one per signed-in user: cache, sync, outbox, media store |
| `InboxController` / `ChatRoomController` | kit | created by `kit.inbox(filter:)` / `kit.room(id)`; **the page disposes them** |
| `InboxView` / `ChatRoomView` | kit | complete screens; they never navigate, taps come back as callbacks |

Widgets never talk to the source directly. Only the kit writes the cache.

## Lifecycle

```dart
final kit = ChatKit(
  currentUserId: uid,
  source: MyChatSource(),
  uploader: MyUploader(),      // null disables media and voice
  users: MyUserResolver(),
  config: const ChatConfig(),
);
await kit.open();              // opens this user's cache, resumes pending sends

MaterialApp(
  builder: (context, child) => ChatKitScope(kit: kit, child: child!),
);

kit.setOnline(online: isConnected); // from your connectivity source

// Sign-out:
await kit.close();             // dispose controllers first
await kit.clearUserData();     // deletes cache, drafts, outbox, media files
```

## Pages

```dart
class InboxPage extends StatefulWidget { ... }

class _InboxPageState extends State<InboxPage> {
  late final _inbox = context.chatKit.inbox();

  @override
  void dispose() {
    _inbox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t.chats)),
    body: InboxView(
      controller: _inbox,
      strings: chatStrings,
      onRoomTap: (room) => context.router.push(RoomRoute(roomId: room.id)),
    ),
  );
}

class _RoomPageState extends State<RoomPage> {
  late final _room = context.chatKit.room(widget.roomId);

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatRoomView(
    controller: _room,          // ChatRoomView includes its own Scaffold
    strings: chatStrings,
    appBar: ChatAppBarOptions(
      actions: [IconButton(icon: const Icon(Icons.call), onPressed: call)],
      onTitleTap: () => context.router.push(RoomInfoRoute(id: widget.roomId)),
    ),
    onForward: (messages) => forward(messages),
  );
}
```

`context.chatKit` reads the kit from `ChatKitScope`; use `late final` so the
controller is created once, on first build.

## Implementing `ChatSource`

```dart
class MyChatSource with ChatSourceDefaults {
  // required: fetchRooms, fetchMessages, events, send, edit, delete, markRead
  // optional (defaults are no-ops): fetchAround, setTyping, react,
  //   setPinned, setMuted
}
```

Rules:

- **Throw `AppFailure`**, never vendor exceptions. Map in the source:
  unavailable / socket → `NetworkFailure`, deadline → `TimeoutFailure`,
  403 → `PermissionFailure`, 404 → `NotFoundFailure`, 401 → `AuthFailure`.
  Only `NetworkFailure` and `TimeoutFailure` make the outbox retry.
- **Pages are newest first.** `before` / `after` are exclusive keyset
  bounds on `(createdAt, id)`; rooms use `(updatedAt, id)`. Fetch
  `limit + 1` rows to compute `hasMore`. For `after`, read ascending and
  reverse.
- **`send` is idempotent on `localId`**: use it as the document id, or a
  unique column with "insert or return existing". Return the confirmed
  message with the server `id` and `createdAt`.
- **Soft delete** (`deletedAt`) so deletions arrive as `Updated` changes.
- **`events(roomId: null)`** = inbox events (`RoomChanged`,
  `PresenceChanged`); **`events(roomId: id)`** = `MessageChanged`,
  `TypingChanged`, `ReceiptChanged` for that room. Include the sender's own
  messages; the kit deduplicates by `localId`, then `id`.
- Decode with `Message.fromJson(json, keys: ChatJsonKeys(...))` /
  `ChatRoom.fromJson`; override only the keys that differ. Dates may be
  ISO strings, epoch milliseconds or `DateTime` (convert Firestore
  `Timestamp` first).
- Emit `Change<T>` values from `lemsa_core_kit`: `Created(item)`,
  `Updated(item)`, `Deleted(id)`.
- **`fetchRooms(filter:)`**: apply what the query supports (types, labels,
  unread; REST: `...filter.toQuery()`), ignore the rest. Never drop rooms
  from a page after the query; the kit filters its cache itself.

Full guides with schema, realtime mapping and uploads ship in the package:
`doc/adapters/firestore.md`, `doc/adapters/supabase.md`,
`doc/adapters/rest_websocket.md`, `doc/adapters/mixing.md`.

## Several chat lists

One controller per list, each with its own paging, search and
`totalUnread` (tab badges):

```dart
late final _chats = context.chatKit.inbox(filter: RoomFilter.direct);
late final _groups = context.chatKit.inbox(filter: RoomFilter.groups);
// also: RoomFilter(labels: {'work'}), RoomFilter(excludeLabels: {'archived'}),
//       RoomFilter(unreadOnly: true), RoomFilter(where: (room) => ...)
// Chips over one list: _inbox.setFilter(RoomFilter.groups);
```

`ChatRoom.labels` are per-user categories from the backend
(`"labels": [...]`).

## Mixing backends

`ChatSource` = `ChatDataSource` (reads, writes; mix in
`ChatDataSourceDefaults`) + `ChatRealtime` (`events`, `setTyping`).

```dart
final api = MyRestApi(); // implements ChatDataSource
ChatKit(
  currentUserId: uid,
  source: ComposedChatSource(
    data: api,
    realtime: SupabaseChatSource(client), // a full adapter works as realtime
    // realtime: PollingRealtime(api),    // REST only: polls open screens
  ),
);
```

Both sides must use the same room / message ids and `localId`s.
`PollingRealtime` needs soft deletes and has no typing or presence.
Two unrelated chat systems → two `ChatKit`s, the second with
`DriftChatCache(executorFactory: (id) => openChatDatabase('support_$id'))`
and its own `ChatMediaStore` user id.

## Sending from code

```dart
await room.sendText('Hi', replyToId: replyTo?.id);
await room.sendCustom('offer', {'title': 'Bike', 'amount': 120});
```

The composer inside `ChatRoomView` handles text, media, voice, reply and
edit. Messages appear immediately as pending, then move to sent, delivered
and read; failed ones show a retry action.

## Customizing

```dart
ChatRoomView(
  controller: room,
  theme: ChatTheme.fallback(scheme).copyWith(bubbleRadius: 12),
  builders: ChatBuilders(
    bubbleBuilder: (context, m, defaultChild) => defaultChild,
    customBuilders: {'offer': (context, m) => OfferCard(message: m)},
    messageActions: (context, m, defaults) => [...defaults, report(m)],
    appBarActions: (context, room) => [infoButton],
    composerBuilder: (context, defaultChild) => defaultChild,
  ),
  extraAttachmentOptions: [
    AttachmentOption(icon: Icons.place, label: t.location, onSelected: share),
  ],
);
```

- Register `ChatTheme` in `ThemeData.extensions` (derive it with
  `ChatTheme.fallback(colorScheme)`), or pass `theme:` for one screen.
- Every builder gets the default widget: wrap it instead of rebuilding it.
- `MessageContext`: `message`, `author`, `isMine`, `groupPosition`,
  `status`, `seenBy`, `repliedTo`, `isSelected`, `room`, `uploadProgress`.
- `RoomContext` (inbox): `room`, `peer`, `lastMessageAuthor`, `presence`,
  `typingNames`.
- A custom type without a builder renders as "unsupported"; set
  `ChatStrings.customPreview` for its inbox and reply preview text.
- For fully custom screens, compose `ChatAppBar`, `ChatMessageList`,
  `ChatComposer`, `MessageContent`, `RoomTile` with the controllers.

## Text

The kit shows **English defaults** and never localizes. Build one
`ChatStrings` from the app's translations and pass it to both views:

```dart
ChatStrings chatStrings(Translations t) => ChatStrings(
  typeMessage: t.chat.typeMessage,
  send: t.chat.send,
  typing: (names) => t.chat.typing(n: names.length, name: names.first),
  members: (count) => t.chat.members(n: count),
  system: (code, args) => t.chat.system(code: code, args: args),
);
```

System messages store only `code` + `args`; `ChatStrings.system` renders
them. Dates and sizes go through `ChatFormatters` (intl).

## Riverpod (app side)

```dart
@riverpod
ChatKit chatKit(Ref ref) {
  final uid = ref.watch(currentUserIdProvider);
  final kit = ChatKit(currentUserId: uid, source: ref.watch(chatSourceProvider));
  ref.onDispose(kit.close);
  return kit;
}
```

Open it before showing chat pages (`await kit.open()` in a `FutureProvider`
or at sign-in), and still provide it to widgets with `ChatKitScope`.

## Platform setup

- Web: serve `sqlite3.wasm` and `drift_worker.js` from `web/`.
- Microphone (voice) and camera / photos (pickers) permissions in
  `AndroidManifest.xml`, `Info.plist`, and macOS entitlements
  (`network.client`, `device.audio-input`, `device.camera`,
  `files.user-selected.read-write`).

## Do not

- Do not put backend SDKs, Riverpod or translations inside the kit's code
  paths; they belong to the app.
- Do not keep a `ChatRoomController` after its page is gone; dispose it.
- Do not call `kit.close()` while controllers are alive.
- Do not create a second `ChatKit` for the same user; share one.
- Do not client-filter or reorder messages; the kit keeps order and paging.
- Do not show failures' text from the kit; map `AppFailure` to your own
  messages.

## Where things go

| Concern | Where |
| --- | --- |
| Firebase / Supabase / REST calls | app `ChatSource` implementation |
| File storage upload | app `ChatUploader` implementation |
| Profiles | app `ChatUserResolver` |
| Riverpod providers | app (wrap `ChatKit` / controllers) |
| Translated strings | app, via `ChatStrings` |
| Push notifications | app (open the room with `kit.room(id)`) |
