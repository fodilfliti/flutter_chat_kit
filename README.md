# flutter_chat_kit

[![pub package](https://img.shields.io/pub/v/flutter_chat_kit.svg)](https://pub.dev/packages/flutter_chat_kit)

Backend-agnostic chat for Flutter. You implement one `ChatSource` for your
backend (Firebase, Supabase, REST, WebSocket, ...). The kit owns the rest:
typed models, a built-in SQLite cache, an offline outbox, controllers, and a
chat room and inbox UI you can customize piece by piece.

**Platforms:** Android, iOS, Linux, macOS, Web, Windows
**Requires:** Flutter `>=3.44.0`

## Features

- **Direct and group chats**: inbox with search, pinning, muting, unread
  badges, typing and presence; room with author names and stacked avatars.
- **Several chat lists**: "Chats" and "Groups" tabs, labels or an unread
  list from one backend, each with its own paging and unread count.
- **Mix backends**: data from a REST API with realtime from Firebase,
  Supabase or a WebSocket, or REST alone with built-in polling.
- **Profiles and businesses**: one account chats as several profiles
  (personal, business pages) and switches between them; a business can be
  answered by several staff members, who see who replied while customers
  see the business.
- **Smooth scrolling at any size**: a center-anchored list that never jumps
  when older pages, newer pages or new messages arrive; jump to any old
  message (for example a reply) with a highlight.
- **Offline first**: rooms and messages are cached in SQLite (one database
  per user). Messages sent offline appear at once, are queued, and are sent
  with retry and backoff when the connection returns, even after a restart.
- **Rich messages**: text with links, images (grid), video, voice messages
  with waveform and speed, files, system messages, and your own custom
  types. Replies, reactions, edit, delete, multi-select, read receipts.
- **Media stored locally**: each file is downloaded once and kept on disk;
  your own uploads are reused without downloading them again; "Save" exports
  a file to the device.
- **Fully customizable**: a `ChatTheme` extension, builders for every part
  (each receives the default widget), replaceable text in any language, and
  public building blocks for fully custom screens.

## Install

```yaml
dependencies:
  flutter_chat_kit: ^0.1.0
```

```dart
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
```

## Quick start

```dart
final kit = ChatKit(
  currentUserId: uid,
  source: MyChatSource(),        // your backend, see "Connect a backend"
  uploader: MyUploader(),        // optional: enables media and voice
  users: MyUserResolver(),       // optional: names and avatars
);
await kit.open();

MaterialApp(
  builder: (context, child) => ChatKitScope(kit: kit, child: child!),
  home: Scaffold(
    body: InboxView(
      controller: inbox,         // kit.inbox(), dispose it with the page
      onRoomTap: (room) => Navigator.of(context).push(MaterialPageRoute(
        // A page that creates kit.room(room.id) and disposes it.
        builder: (_) => RoomPage(roomId: room.id),
      )),
    ),
  ),
);
```

Controllers belong to the page that creates them: create
`kit.inbox()` / `kit.room(id)` in the page's state and dispose them in
`dispose`. `RoomPage` then returns `ChatRoomView(controller: room)`, a
complete screen with app bar, messages and composer.
On sign-out, call `await kit.close()` then `await kit.clearUserData()`, and
create a new `ChatKit` for the next user.

## Connect a backend

Implement `ChatSource` (mix in `ChatSourceDefaults` to skip the optional
capabilities):

```dart
class MyChatSource with ChatSourceDefaults {
  @override
  Future<ChatPage<ChatRoom>> fetchRooms({RoomCursor? after, int limit = 20,
      String? search, RoomFilter filter = RoomFilter.all}) { ... }

  @override
  Future<ChatPage<Message>> fetchMessages(String roomId,
      {MessageCursor? before, MessageCursor? after, int limit = 30}) { ... }

  @override
  Stream<ChatEvent> events({String? roomId}) { ... }

  @override
  Future<Message> send(Message pending) { ... }

  @override
  Future<Message> edit(Message message) { ... }

  @override
  Future<void> delete(String roomId, String messageId) { ... }

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) { ... }
}
```

The rules that keep the cache consistent:

- Throw `AppFailure`s from `lemsa_core_kit`, never vendor exceptions.
  `NetworkFailure` and `TimeoutFailure` make the outbox retry.
- Message pages are **newest first**; cursors are exclusive keyset bounds on
  `(createdAt, id)`.
- `send` is **idempotent on `localId`** (use it as the document id or a
  unique key), so a retry never duplicates a message.
- `events` also delivers the sender's own messages; the kit deduplicates.

`Message.fromJson` / `toJson` and `ChatRoom.fromJson` cover the usual JSON
shape; pass `ChatJsonKeys(...)` when your field names differ.

Step-by-step guides, with schema, realtime mapping and uploads:

- [Firestore](doc/adapters/firestore.md)
- [Supabase](doc/adapters/supabase.md)
- [REST + WebSocket](doc/adapters/rest_websocket.md)
- [Several chat lists and mixed backends](doc/adapters/mixing.md)
- [Profiles and business accounts](doc/adapters/profiles.md)

Call `kit.setOnline(online: ...)` from your connectivity source. Going online
fills the gaps of open rooms, refreshes open chat lists and flushes the
outbox.

### Several chat lists

Create one `InboxController` per list; each has its own filter, paging,
search and `totalUnread`:

```dart
final chats = kit.inbox(filter: RoomFilter.direct);
final groups = kit.inbox(filter: RoomFilter.groups);
final work = kit.inbox(filter: const RoomFilter(labels: {'work'}));
// Chips over one list: inbox.setFilter(const RoomFilter(unreadOnly: true));
```

The filter reaches `fetchRooms` so the backend can apply it, and the kit
filters its cache again, so a backend that ignores it still works.

### Mixing backends

`ChatSource` is a `ChatDataSource` (reads and writes) plus a
`ChatRealtime` (events and typing). Take each half from a different
service:

```dart
final api = MyRestApi(); // implements ChatDataSource
final source = ComposedChatSource(
  data: api,
  realtime: SupabaseChatSource(supabase), // or Firestore, a WebSocket, ...
  // realtime: PollingRealtime(api),      // REST only, no realtime service
);
```

### Profiles and business accounts

When one account owns several profiles (personal, business pages), let a
`ChatProfileSwitcher` hold one kit per profile. Only the active one is
open, with its own database and media folder:

```dart
final switcher = ChatProfileSwitcher(
  profiles: [
    ChatProfile(id: uid, name: 'Ali'),
    ChatProfile(id: shopId, name: 'Lemsa Shop',
        kind: ChatProfileKind.business, agentId: uid),
  ],
  createKit: (profile) => ChatKit(
    currentUserId: profile.id,   // rooms and messages belong to the profile
    agentId: profile.agentId,    // staff member, stamped as Message.sentBy
    source: MyChatSource(actingAs: profile.id),
  ),
);
await switcher.open();

MaterialApp(
  builder: (context, child) =>
      ChatProfileScope(switcher: switcher, child: child!),
  // ChatProfileMenuButton() in the inbox app bar switches profiles.
);
```

Staff on a shared business profile see which colleague sent each message;
customers only see the business. Backend authorization and schemas are in
the [profiles guide](doc/adapters/profiles.md).

## Platform setup

**Web.** The SQLite cache runs in a web worker. Copy two files into your
app's `web/` folder:

- `sqlite3.wasm` from the
  [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases)
  (the version matching the `sqlite3` package in your `pubspec.lock`);
- `drift_worker.js` from the
  [drift releases](https://github.com/simolus3/drift/releases) (matching
  `drift`).

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Record voice messages.</string>
<key>NSCameraUsageDescription</key>
<string>Take photos and videos to send.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Send photos and videos from your library.</string>
```

**macOS**: add the same microphone and camera keys to `Info.plist`, and these
entitlements to both `DebugProfile.entitlements` and `Release.entitlements`:
`com.apple.security.network.client`,
`com.apple.security.device.audio-input`,
`com.apple.security.device.camera`,
`com.apple.security.files.user-selected.read-write`.

**Linux**: voice playback uses GStreamer
(`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`).
**Windows and Linux**: `video_player` has no official desktop
implementation; add one (for example `video_player_win` or `fvp`) if you
need in-app video playback there.

## Customize

```dart
ChatRoomView(
  controller: room,
  theme: ChatTheme.fallback(scheme).copyWith(bubbleRadius: 12),
  strings: ChatStrings(typeMessage: 'Écrire un message', send: 'Envoyer'),
  appBar: ChatAppBarOptions(actions: [callButton]),
  builders: ChatBuilders(
    bubbleBuilder: (context, m, defaultChild) => defaultChild,
    customBuilders: {'offer': (context, m) => OfferCard(message: m)},
    messageActions: (context, m, defaults) => [...defaults, reportAction(m)],
  ),
  extraAttachmentOptions: [locationOption],
  onForward: (messages) => pickRoomAndForward(messages),
)
```

- **Theme**: register `ChatTheme` in `ThemeData.extensions`, or pass it to
  a single screen.
- **Builders**: `ChatBuilders` for the room and `InboxBuilders` for the
  inbox. Each builder gets the default widget, so wrapping is one line.
- **Text**: every string is in `ChatStrings`, in English by default. Map it
  from slang, intl or any other localization tool.
- **Formats**: `ChatFormatters` for times, dates, durations and sizes.
- **Behavior**: `ChatConfig` for page sizes, grouping, reactions,
  auto-download and limits.

See the [customization cookbook](doc/customization.md) for recipes.

## Example

[`example/`](example) is a complete app on an in-memory fake backend:
inbox, direct and group rooms, a 5 000-message room, a custom "offer"
message, a personal and a business profile with staff replies, an offline
toggle and random send failures. No accounts or keys needed:

```bash
cd example
flutter run
```

## Agent skill

```bash
npx skills add fodilfliti/flutter_chat_kit
# or: npx skills add fodilfliti/lemsa-skills
```

## Links

- [GitHub](https://github.com/fodilfliti/flutter_chat_kit)
- [Issues](https://github.com/fodilfliti/flutter_chat_kit/issues)
- [Lemsa skills](https://github.com/fodilfliti/lemsa-skills)
