# flutter_chat_pro

[![pub package](https://img.shields.io/pub/v/flutter_chat_pro.svg)](https://pub.dev/packages/flutter_chat_pro)

A complete chat for Flutter that works with **any backend**. You write one
class that talks to your server (Firebase, Supabase, REST, WebSocket, ...).
The kit does everything else: the inbox and chat room screens, an offline
cache, a send queue, media, voice messages, read receipts, and styling.

**Platforms:** Android, iOS, Linux, macOS, Web, Windows
**Requires:** Flutter `>=3.44.0`

| Inbox and styling | Chat room | Custom messages and offline |
| :---: | :---: | :---: |
| ![Inbox, languages and style presets](https://raw.githubusercontent.com/fodilfliti/flutter_chat_kit/main/doc/media/demo_1.gif) | ![Chat room with replies and reactions](https://raw.githubusercontent.com/fodilfliti/flutter_chat_kit/main/doc/media/demo_2.gif) | ![Attachments, custom messages and offline mode](https://raw.githubusercontent.com/fodilfliti/flutter_chat_kit/main/doc/media/demo_3.gif) |

[Watch the full demo video (73 s)](https://github.com/fodilfliti/flutter_chat_kit/blob/main/doc/media/chat_kit_demo.mp4)

### 🎯 [Try the live demo in your browser →](https://fodilfliti.github.io/flutter_chat_kit/)

The [example app](example/) on a fake backend, inside a phone frame: pick a
device, switch presets and languages, go offline, turn on incoming messages.

> **Using an AI agent?** Run `npx skills add fodilfliti/flutter_chat_kit`,
> then ask: *"Add a chat to this app with flutter_chat_pro."* See
> [Let your AI agent build it](#let-your-ai-agent-build-it).

## Contents

- [Features](#features)
- [Before you start: what to install and write](#before-you-start-what-to-install-and-write)
  - [1. Add the packages](#1-add-the-packages)
  - [2. Platform setup](#2-platform-setup)
  - [3. The classes you write](#3-the-classes-you-write)
- [Quick start: a working chat in 3 steps](#quick-start-a-working-chat-in-3-steps)
  - [0. No backend yet? Start on fake data](#0-no-backend-yet-start-on-fake-data)
  - [Text only, voice or attachments](#text-only-voice-or-attachments)
- [How the pieces fit](#how-the-pieces-fit)
- [Connect your backend](#connect-your-backend)
  - [Pick your path](#pick-your-path)
  - [The JSON the kit reads](#the-json-the-kit-reads)
  - [Your field names, camelCase, or a mapper](#your-field-names-camelcase-or-a-mapper)
  - [The ChatSource](#the-chatsource)
  - [Names and avatars](#names-and-avatars)
- [Media, sync and push](#media-sync-and-push)
  - [Photos and videos](#photos-and-videos)
  - [Staying in sync](#staying-in-sync)
  - [Push notifications](#push-notifications)
  - [APIs that page by number](#apis-that-page-by-number)
- [Style the chat](#style-the-chat)
- [Builders, text and custom messages](#builders-text-and-custom-messages)
  - [Several custom message types](#several-custom-message-types)
- [Example app](#example-app)
- [Screen size and theme kits](#screen-size-and-theme-kits)
- [Troubleshooting](#troubleshooting)
- [Let your AI agent build it](#let-your-ai-agent-build-it)

## Features

- **Direct and group chats**: inbox with search, pinning, muting, unread
  badges, typing and online status; rooms with author names and avatars.
- **Several chat lists**: "Chats" and "Groups" tabs, labels, or an unread
  list, each with its own paging and unread count.
- **Mix backends**: data from a REST API with realtime from Firebase,
  Supabase or a WebSocket, or REST alone with built-in polling.
- **Profiles and businesses**: one account chats as several profiles
  (personal, business pages); staff answer for a business together.
- **Offline first**: rooms and messages are cached in SQLite. Messages sent
  offline show at once and are sent when the connection returns, even
  after a restart.
- **Rich messages**: text with links, images, video, voice with waveform,
  files, system messages and your own custom types. Replies, reactions,
  edit, delete, multi-select, read receipts.
- **Media stored locally**: each file is downloaded once and kept on disk.
  Photos are shrunk before upload, videos get a poster, and you can plug
  in a video compressor.
- **Stays in sync**: catches up when the app comes back, reconnects
  dropped live streams, pauses sending on an expired token, and works with
  APIs that page by number.
- **Smooth at any size**: the message list never jumps when pages or new
  messages arrive, and can jump to any old message.
- **Easy to style**: one `ChatStyle` widget with presets (WhatsApp,
  Telegram, ...), simple options and screen scaling that works with any
  scale package.

## Before you start: what to install and write

Do these three things once. Everything after this section builds on them.

**Requirements:** Flutter `>=3.44.0` (Dart `^3.12.0`).

### 1. Add the packages

```yaml
dependencies:
  flutter_chat_pro: ^0.1.0
  lemsa_core_kit: ^1.1.0 # the AppFailure errors your ChatSource throws
```

```dart
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart'; // in your ChatSource file
```

The kit brings its own SQLite cache, media cache, pickers, voice recorder
and players. You do **not** add a backend SDK to the kit: your app already
has Firebase, Supabase or an HTTP client, and only your `ChatSource` uses it.

### 2. Platform setup

Only the platforms you ship need it.

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

**macOS**: the same microphone and camera keys in `Info.plist`, and these
entitlements in both `DebugProfile.entitlements` and
`Release.entitlements`: `com.apple.security.network.client`,
`com.apple.security.device.audio-input`,
`com.apple.security.device.camera`,
`com.apple.security.files.user-selected.read-write`.

**Web.** The SQLite cache runs in a web worker and needs two files in your
app's `web/` folder (`sqlite3.wasm` and `drift_worker.js`). One command
downloads the versions that match your `pubspec.lock`:

```bash
dart run flutter_chat_pro:web_setup
```

Run it from your app folder after `flutter pub get`, and again after
upgrading drift or sqlite3. Commit the two files, or run the command in CI
before `flutter build web`.

**Linux**: voice playback uses GStreamer
(`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`).

**Windows and Linux**: `video_player` has no official desktop
implementation; add one (for example `video_player_win` or `fvp`) for
in-app video there.

### 3. The classes you write

| Class | Needed? | What it does |
| --- | --- | --- |
| `ChatSource` | **Always** | Reads and writes rooms and messages on your backend, and sends live events. See [Connect your backend](#connect-your-backend). Until it's ready, use the built-in `InMemoryChatSource`. |
| `ChatUploader` | For photos, video, files and voice | Uploads one file to your storage and returns its URL. Without it the attach and mic buttons are hidden. To hide just one of them, see [Text only, voice or attachments](#text-only-voice-or-attachments). |
| `ChatUserResolver` | Optional | Looks up names and avatars your backend did not send. Not needed when your API returns them with rooms and messages, see [Names and avatars](#names-and-avatars). |

```dart
class MyUploader implements ChatUploader {
  @override
  Stream<UploadProgress> upload(Attachment attachment,
      {required String roomId, required String localId}) async* {
    // Read the file with attachment.openRead() (a stream, best for videos)
    // or attachment.readAsBytes(). Both work on web, where File(localPath)
    // fails. Upload it to Firebase Storage, Supabase Storage, S3...
    yield const UploadRunning(0.5);           // optional progress, 0..1
    yield UploadDone(remoteUrl: downloadUrl); // always end with this
  }
}

class MyUserResolver implements ChatUserResolver {
  @override
  Future<List<ChatUser>> resolve(Set<String> ids) async {
    // One request for many ids; missing ids are simply left out.
    final rows = await api.getUsers(ids);
    return [for (final row in rows) ChatUser.fromJson(row)];
  }
}
```

[Firestore](doc/adapters/firestore.md),
[Supabase](doc/adapters/supabase.md) and
[REST + WebSocket](doc/adapters/rest_websocket.md) guides contain a full
`ChatSource` and `ChatUploader` for each backend, ready to copy.

## Quick start: a working chat in 3 steps

### 0. No backend yet? Start on fake data

`InMemoryChatSource` is a complete backend kept in memory: sample chats and
people, paging, sending, read receipts, typing and auto replies. Use it to
build and style your screens before writing any server code:

```dart
final kit = ChatKit(
  currentUserId: 'me',
  source: InMemoryChatSource.sample(currentUserId: 'me'),
);
```

Follow the steps below with it, then replace it with your own `ChatSource`
(see [Connect your backend](#connect-your-backend)). Nothing else changes.

### 1. Create the kit and put it above your app

`ChatKit` is the chat engine for the signed-in user. Create it after login
and open it:

```dart
final kit = ChatKit(
  currentUserId: user.id,
  source: MyChatSource(),     // your backend, see "Connect your backend"
  uploader: MyUploader(),     // optional: enables photos, files and voice
  users: MyUserResolver(),    // optional: names your API did not send
);
await kit.open();

runApp(
  MaterialApp(
    builder: (context, child) => ChatKitScope(kit: kit, child: child!),
    home: const InboxPage(),
  ),
);
```

`ChatKitScope` lets any page find the kit with `ChatKitScope.of(context)`.

### 2. The inbox page

A controller belongs to the page that creates it: create it in `State`,
dispose it in `dispose`.

```dart
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final InboxController inbox = ChatKitScope.of(context).inbox();

  @override
  void dispose() {
    inbox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: InboxView(
        controller: inbox,
        // Tapping a chat opens this page.
        roomBuilder: (context, room) => RoomPage(roomId: room.id),
      ),
    );
  }
}
```

### 3. The room page

`ChatRoomView` is a full screen: app bar, messages and message box.

```dart
class RoomPage extends StatefulWidget {
  const RoomPage({required this.roomId, super.key});

  final String roomId;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final ChatRoomController room =
      ChatKitScope.of(context).room(widget.roomId);

  @override
  void dispose() {
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatRoomView(controller: room);
}
```

That's a working chat. It already follows your app's colors, fonts and
dark mode. On sign-out call `await kit.close()` then
`await kit.clearUserData()`, and create a new `ChatKit` for the next user.

### Text only, voice or attachments

Start with text only and add media later. Without a `ChatUploader` the
kit hides the attach and mic buttons. Once you pass an uploader, both
show up. To keep one of them hidden:

```dart
ChatRoomView(
  controller: room,
  enableVoice: false,       // no mic button
  enableAttachments: false, // no attach button
);
```

## How the pieces fit

| Piece | What it does |
| --- | --- |
| `ChatSource` | The only class you write: talks to your backend. |
| `ChatKit` | The engine: cache, send queue, media. One per signed-in user. |
| `InboxController` / `ChatRoomController` | Data for one list / one room. Made by `kit.inbox()` / `kit.room(id)`. |
| `InboxView` / `ChatRoomView` | The ready-made screens. |
| `ChatStyle` | Changes how everything below it looks, and its size. |
| `ChatStrings` | Every text the chat shows, English by default. |

## Connect your backend

You write one class, `ChatSource`, that turns your backend's data into kit
models. The kit never talks to your server itself.

### Pick your path

| Your backend | Start here |
| --- | --- |
| Nothing yet, or still in design | `InMemoryChatSource` ([step 0](#0-no-backend-yet-start-on-fake-data)), then build your API on [the kit's JSON](doc/backend_json.md) |
| Firebase (Firestore) | [Firestore guide](doc/adapters/firestore.md): schema, rules, realtime, Storage uploads |
| Supabase | [Supabase guide](doc/adapters/supabase.md): tables, RLS, realtime, Storage uploads |
| A new REST API (you choose the JSON) | [REST + WebSocket guide](doc/adapters/rest_websocket.md) with the [JSON contract](doc/backend_json.md) |
| An existing API with its own JSON | [Plug in an existing API](doc/adapters/your_api.md): keys, camelCase, mappers, polling |
| REST data, realtime elsewhere, or no realtime | [Mixing backends](doc/adapters/mixing.md): `ComposedChatSource`, `PollingRealtime` |
| One account with several profiles | [Profiles and business accounts](doc/adapters/profiles.md) |

### The JSON the kit reads

The smallest message is four fields:

```json
{ "id": "m1", "author_id": "u2", "created_at": "2026-09-30T12:00:00Z", "text": "Hi" }
```

Decoding forgives what real APIs send:

- **Ids** can be numbers.
- **Dates** can be ISO-8601, epoch milliseconds or epoch seconds.
- **`room_id` can be left out**: pass it with `Message.fromJson(json, roomId: id)`.
- **An attachment can be just a URL** (`"attachment": "https://.../a.jpg"`).
  Its type is guessed from the extension, or from the message type.
- **A room without `updated_at`** takes the time of its last message.
- **Members can be plain user ids.**
- **`status: "read"`** is understood, in any case.
- **Unknown types** become a `CustomMessage` you can draw.

Every field, every type, and what you lose without each optional one:
[Backend JSON](doc/backend_json.md).

### Your field names, camelCase, or a mapper

Rename only what differs:

```dart
const keys = ChatJsonKeys(
  authorId: 'sender_id',
  createdAt: 'sent_at',
  typeAliases: {'photo': 'image', 'voice': 'audio'},
  attachmentKeys: AttachmentJsonKeys(remoteUrl: 'file_url'),
);
final message = Message.fromJson(json, keys: keys, roomId: roomId);
final room = ChatRoom.fromJson(json, keys: keys);
```

camelCase API? One line:

```dart
final message = Message.fromJson(json, keys: ChatJsonKeys.camelCase, roomId: roomId);
```

Nested JSON (`"sender": {"id": 7}`, a `files` array)? Reshape the map, then
let `Message.fromJson` handle dates, ids and media types:

```dart
Message toMessage(Map<String, Object?> m, String roomId) => Message.fromJson({
  'id': m['messageId'],
  'local_id': m['clientId'],
  'author_id': (m['sender']! as Map)['id'],
  'created_at': m['sentAt'],
  'type': m['kind'] == 'photo' ? 'image' : 'text',
  'text': m['body'],
  'attachments': [for (final f in m['files'] as List? ?? []) (f as Map)['url']],
}, roomId: roomId);
```

Then check a saved real response once in a test. `ChatJsonCheck` names
each field it can't read, or reads with a guess, and the fix:

```dart
expect(ChatJsonCheck.message(json, keys: keys, roomId: 'r1'), isEmpty);
```

### The ChatSource

Mix in `ChatSourceDefaults` and only seven methods are left; reactions,
pin, mute, typing and jump-to-message become optional:

```dart
class MyChatSource with ChatSourceDefaults {
  MyChatSource(this.api);

  final MyApi api; // your HTTP client, Firebase, Supabase, ...

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({RoomCursor? after, int limit = 20,
      String? search, RoomFilter filter = RoomFilter.all}) async {
    final res = await api.get('/rooms', {'after': after?.updatedAt, 'limit': limit, 'q': search});
    return ChatPage(
      items: [for (final r in res['items']) ChatRoom.fromJson(r)],
      hasMore: res['has_more'] == true,
      users: [for (final u in res['users'] ?? []) ChatUser.fromJson(u)],
    );
  }

  @override
  Future<ChatPage<Message>> fetchMessages(String roomId,
      {MessageCursor? before, MessageCursor? after, int limit = 30}) async {
    final res = await api.get('/rooms/$roomId/messages', {
      'before': before?.createdAt, 'after': after?.createdAt, 'limit': limit,
    });
    return ChatPage(
      items: [for (final m in res['items']) Message.fromJson(m, roomId: roomId)],
      hasMore: res['has_more'] == true,
    );
  }

  @override
  Future<Message> send(Message pending) async => Message.fromJson(
    await api.put('/rooms/${pending.roomId}/messages/${pending.localId}', pending.toJson()),
  );

  @override
  Future<Message> edit(Message message) async => Message.fromJson(
    await api.patch('/rooms/${message.roomId}/messages/${message.id}', message.toJson()),
  );

  @override
  Future<void> delete(String roomId, String messageId) =>
      api.delete('/rooms/$roomId/messages/$messageId');

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) =>
      api.post('/rooms/$roomId/read', upTo.toJson());

  @override
  Stream<ChatEvent> events({String? roomId}) => api.socketEvents(roomId);
}
```

Four rules keep the cache correct:

- Throw `AppFailure`s from `lemsa_core_kit`, never vendor exceptions.
  `NetworkFailure` and `TimeoutFailure` make the send queue retry.
- Message pages are **newest first**. Cursors are exclusive bounds on
  `(createdAt, id)`.
- `send` must be **idempotent on `localId`** (use it as the document id or a
  unique key), so a retry never creates a duplicate. Return the saved
  message with the same `local_id`.
- `events` also delivers your own messages; the kit removes duplicates.
  No realtime service? Use `PollingRealtime`
  ([mixing backends](doc/adapters/mixing.md#rest-only-pollingrealtime)).

Call `kit.setOnline(online: ...)` from your connectivity check: going
online fills gaps, refreshes lists and sends queued messages.

### Names and avatars

Most REST APIs and Supabase queries already return the author's name and
avatar with the rooms and messages. Give them to the kit: it saves them in
its cache, shows them in the inbox and rooms, and **replaces them when they
change** (a user renames, uploads a new photo, a business changes its logo).

**1. Send them with each page** (the usual way). Put the people of the page
in `ChatPage.users`, in `fetchRooms`, `fetchMessages` and `fetchAround`:

```dart
// REST: { "messages": [...], "users": [{"id", "name", "avatar_url"}], "has_more": true }
final json = await api.get('/rooms/$roomId/messages', query: {...});
return ChatPage(
  items: [for (final m in json['messages']) Message.fromJson(m)],
  hasMore: json['has_more'] as bool,
  users: [for (final u in json['users']) ChatUser.fromJson(u)],
);
```

```dart
// Supabase: embed the author's profile in the same query.
final rows = await supabase
    .from('messages')
    .select('*, author:profiles!author_id(id, name, avatar_url)')
    .eq('room_id', roomId)
    .order('created_at', ascending: false)
    .limit(limit + 1);
return ChatPage(
  items: [for (final r in rows.take(limit)) Message.fromJson(r)],
  hasMore: rows.length > limit,
  users: [
    for (final r in rows)
      if (r['author'] case final Map<String, dynamic> author)
        ChatUser.fromJson(author),
  ],
);
```

Every time a page loads, the kit compares the users with the saved ones and
updates the screen if a name or avatar is different. Duplicates in the list
are fine.

**2. Push changes as they happen** (optional). When your realtime service
says a profile changed, emit `UsersChanged` from `events()`:

```dart
// in events(): a "user.updated" WebSocket message, a Supabase change on profiles, ...
out.add(UsersChanged([ChatUser.fromJson(payload)]));
```

or call the kit from anywhere in your app, for example right after the user
edits their own profile:

```dart
await kit.updateUsers([ChatUser(id: me.id, name: newName, avatarUrl: newUrl)]);
```

**3. A resolver for the rest** (optional). If some ids still have no name
(for example the peer of a room whose API returns only ids), the kit asks
your `ChatUserResolver` for them, many ids in one call. It asks again after
`ChatConfig.userCacheTtl` (12 hours by default) to pick up changes. Users
that came with pages or events count as fresh, so the resolver is not asked
for them.

How it behaves:

- The newest value wins, wherever it came from.
- Open inboxes and rooms update at once; nothing to refresh by hand.
- Names are saved in SQLite, so they show offline and right after a restart.
- `PollingRealtime` (REST without realtime) compares the users of each
  poll and emits `UsersChanged` for you.
- `ChatUser.metadata` keeps extra fields (role, verified badge, ...) and is
  compared too.

### Several chat lists (tabs)

Make one controller per list. Each has its own filter, paging, search and
unread count, so three tabs work on their own and all stay live:

```dart
late final chats = kit.inbox(filter: RoomFilter.direct);
late final groups = kit.inbox(filter: RoomFilter.groups);
late final work = kit.inbox(filter: const RoomFilter(labels: {'work'}));

// Badge on a tab: rebuilds when the unread count changes.
ListenableBuilder(
  listenable: chats,
  builder: (context, _) => Badge.count(
    count: chats.totalUnread,
    isLabelVisible: chats.totalUnread > 0,
    child: const Text('Chats'),
  ),
);
```

Reading a message in any tab updates the others, because they share one
cache. The filter is sent to `fetchRooms`, and the kit also filters its
cache, so a backend that ignores filters still works.

### Mixing backends

`ChatSource` is two halves: data (reads and writes) and realtime (events
and typing). Take each half from a different service:

```dart
final source = ComposedChatSource(
  data: MyRestApi(),                      // implements ChatDataSource
  realtime: SupabaseChatSource(supabase), // or Firestore, a WebSocket, ...
  // realtime: PollingRealtime(api),      // REST only, no realtime service
);
```

### Profiles and business accounts

When one account owns several profiles, `ChatProfileSwitcher` keeps one kit
per profile, each with its own database:

```dart
final switcher = ChatProfileSwitcher(
  profiles: [
    ChatProfile(id: uid, name: 'Ali'),
    ChatProfile(id: shopId, name: 'Lemsa Shop',
        kind: ChatProfileKind.business, agentId: uid),
  ],
  createKit: (profile) => ChatKit(
    currentUserId: profile.id,
    agentId: profile.agentId, // the staff member who sends
    source: MyChatSource(actingAs: profile.id),
  ),
);
await switcher.open();

MaterialApp(
  builder: (context, child) =>
      ChatProfileScope(switcher: switcher, child: child!),
  // Put ChatProfileMenuButton() in the inbox app bar to switch profiles.
);
```

Staff see which colleague sent each message; customers only see the
business. See the [profiles guide](doc/adapters/profiles.md).

## Media, sync and push

### Photos and videos

Photos picked with the built-in picker are scaled so their longest side is
at most 1920 px and saved as JPEG at quality 80; iPhone HEIC photos become
JPEG on the way. A camera shot of several MB usually ends up a few hundred
KB. Change or turn it off in `ChatConfig`:

```dart
const ChatConfig(
  imageMaxDimension: 2560, // null sends the original size
  imageQuality: 90,        // null keeps the original encoding
  maxAttachmentBytes: 50 * 1024 * 1024,
);
```

Files picked with "File" are sent untouched, which is also the way to send
a GIF that must stay animated on every Android version. If you replace the
picker (`onAttachmentPick`), shrink photos the same way, for example with
`image_picker`'s `maxWidth`, `maxHeight` and `imageQuality`.

Videos picked on Android, iOS and the web get a poster at once: the kit
takes the first frame (480 px) and the bubble shows it while the video
uploads. If your `ChatUploader` returns no `thumbnailUrl`, the kit uploads
the poster through it too (local id `<localId>_thumb`) and sends its URL,
so the other side sees a poster. Desktop shows a placeholder.

**Compress videos before upload.** Phones record about 100 MB a minute.
The kit has no compressor built in (it would add a large native library to
every app), but it runs yours. With
[video_compress](https://pub.dev/packages/video_compress):

```dart
ChatConfig(
  compressVideo: (video) async {
    final info = await VideoCompress.compressVideo(
      video.path,
      quality: VideoQuality.Res1280x720Quality,
    );
    final path = info?.path;
    if (path == null) return video; // keep the original
    return XFile(path, mimeType: 'video/mp4');
  },
);
```

The bubble shows "Compressing" meanwhile (`ChatStrings.compressing`). If
the function throws, the original is sent. `maxAttachmentBytes` is checked
on the compressed file, so a long video can be picked and still fit.

### Staying in sync

The kit keeps the chat current on its own:

- **Back from the background** (after `ChatConfig.resumeResyncAfter`, 5 s):
  it reconnects dropped live streams, fetches what open rooms and inbox
  lists missed, and sends what is queued. Turn it off with
  `resyncOnResume: false`.
- **A live stream that fails or ends** is subscribed again with backoff,
  and the room fetches what it missed. Errors arrive on `kit.syncErrors`.
- **Opening a room after a long time**: the newest page shows first, then
  the kit walks back until it meets the cache, at most 5 requests even for
  1000 new messages. The rest loads as the user scrolls.
- **Back online**: call `kit.setOnline(online: true)` from your
  connectivity listener, or `await kit.refresh()` for pull to refresh.
- **Expired token**: throw `AuthFailure(AuthReason.expired)` from your
  source or uploader. Sending pauses (nothing turns red) and
  `onAuthExpired` is called; refresh, then `kit.retryPending()`. See
  [Troubleshooting](#troubleshooting).
- **A wrong phone clock**: new messages are stamped with
  `kit.serverNow()`, the device clock corrected from your server's
  `created_at`, so they don't sort above replies that arrive meanwhile.

```dart
kit.syncErrors.listen((failure) => log('chat sync: $failure'));
```

### Push notifications

The kit doesn't send pushes, but gives you what a push flow needs:
`kit.activeRoomId` (skip the notification for the room on screen),
`InboxController.totalUnread` for the badge, and `kit.refresh()`. The
[push guide](doc/push.md) covers Firebase Messaging end to end: opening the
room from a tap after a cold start, foreground notifications, and why iOS
needs a visible alert.

### APIs that page by number

If your messages endpoint takes `?page=3` or `?offset=60` instead of a
cursor, `PagedMessages` adapts it to `fetchMessages`, dropping the
duplicates that new messages cause:

```dart
final paged = PagedMessages(
  fetchPage: (roomId, {required page, required size}) =>
      api.getMessages(roomId, page: page, size: size), // raw JSON list
  decode: (json, roomId) => Message.fromJson(json, roomId: roomId),
);

@override
Future<ChatPage<Message>> fetchMessages(String roomId,
        {MessageCursor? before, MessageCursor? after, int limit = 30}) =>
    paged.fetch(roomId, before: before, after: after, limit: limit);
```

See [Plug in an existing API](doc/adapters/your_api.md#2-map-your-endpoints).

## Style the chat

### Step 0: do nothing

With no styling at all, the chat uses your `ThemeData`: its colors, fonts
and dark mode. Change your app theme and the chat follows.

### Step 1: wrap it in `ChatStyle`

`ChatStyle` changes the look of **every chat widget below it**. Put it
around the inbox; rooms opened from the inbox keep the same style:

```dart
ChatStyle(
  preset: ChatPreset.whatsApp,  // a ready look (optional)
  bubbleRadius: 12,             // then change what you want
  tiles: ChatTiles.divided,
  child: InboxView(
    controller: inbox,
    roomBuilder: (context, room) => RoomPage(roomId: room.id),
  ),
)
```

All options are optional. Write sizes as **design numbers** (the size on
your design); scaling is done for you (see
[Screen size](#screen-size-and-theme-kits)).

| Option | What it changes | Example |
| --- | --- | --- |
| `preset` | A complete look | `ChatPreset.telegram` |
| `seedColor` | Chat colors from one color (light and dark) | `Colors.teal` |
| `bubbleRadius` | Bubble corners | `8` |
| `bubbleShadows` | Soft shadow under bubbles | `true` |
| `bubbleBorder` | Thin outline around bubbles | `true` |
| `messageStyle` | Message text (merged) | `TextStyle(fontSize: 15)` |
| `fontFamily` | Font of every chat text | `'Inter'` |
| `tiles` | Inbox rows: plain, divided or cards | `ChatTiles.cards` |
| `tileRadius` | Corners of card rows | `20` |
| `squareAvatars` | Rounded squares instead of circles | `true` |
| `wallpaper` | Behind the messages | `BoxDecoration(color: ...)` |
| `customize` | Anything else (see below) | `(theme) => ...` |
| `scale` | Size for the current screen | `(context) => ChatScale(1.w, text: 1.sp)` |

**Presets:** `ChatPreset.classic`, `whatsApp`, `whatsAppNew`, `telegram`,
`iMessage`, `messenger`, `minimal`, `cards` and `glass` (all in
`ChatPreset.values`, handy for a settings screen). A preset only gives
defaults: any option you pass wins.

| Preset | Look |
| --- | --- |
| `whatsApp` | Classic WhatsApp: green and white bubbles with tails, beige wallpaper, lined rows |
| `whatsAppNew` | Today's WhatsApp: pill bubbles without tails, frameless photos, a composer floating on the wallpaper |
| `telegram` | Gradient outgoing bubbles over a gradient background |
| `iMessage` | Blue and grey bubbles, plain background, outlined input |
| `messenger` | Blue to pink gradient bubbles, light grey incoming ones |
| `minimal` | Flat bordered bubbles, grey text, square avatars |
| `cards` | Round bubbles with shadows, card rows |
| `glass` | Frosted see-through bubbles and input over an aurora gradient |

### Step 2: change anything with `customize`

`ChatTheme` has one style per part of the chat (bubbles, message list,
composer, app bar, avatars, inbox rows, badges, ...). `customize` receives
the theme after the options and returns your changed copy:

```dart
ChatStyle(
  preset: ChatPreset.minimal,
  customize: (theme) => theme.copyWith(
    incomingBubble: theme.incomingBubble.copyWith(color: Colors.white),
    outgoingBubble: theme.outgoingBubble.copyWith(
      gradient: const LinearGradient(colors: [Colors.indigo, Colors.purple]),
    ),
  ),
  child: ...,
)
```

Helpers: `theme.mapBubbles((b) => b.copyWith(...))` changes both bubbles,
`theme.withMessageText(style)` the message text, `theme.mapText(...)` every
text style.

### Where to put it

- **Only the chat part of your app:** wrap the inbox page (as above). The
  rest of your app is untouched.
- **Every chat in the app:** wrap once in `MaterialApp.builder`:

  ```dart
  builder: (context, child) => ChatKitScope(
    kit: kit,
    child: ChatStyle(preset: ChatPreset.telegram, child: child!),
  ),
  ```

- **One screen different:** put another `ChatStyle` inside. It changes only
  what you pass and keeps the rest (and never scales twice):

  ```dart
  ChatStyle(bubbleRadius: 4, child: SupportRoomPage())
  ```

### Opening rooms and other pages

- `InboxView(roomBuilder: ...)` opens the room and keeps the style. This is
  the easy way.
- Your own navigation (go_router, auto_route, ...): use `onRoomTap` and
  wrap the page with `ChatStyle.carry`:

  ```dart
  onRoomTap: (room) {
    final keepStyle = ChatStyle.carry(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => keepStyle(RoomPage(roomId: room.id)),
    ));
  },
  ```

- Any other chat page: `ChatStyle.push(context, (context) => MyPage())`.

Sheets, dialogs and the media viewer opened from the chat keep the style
automatically. Pages opened this way also follow later changes (for
example a style settings screen).

### Use the chat look in your own widgets

```dart
final chat = context.chatTheme;
Container(
  color: chat.incomingBubble.color,
  padding: EdgeInsets.all(chat.size(8)),            // 8, scaled like the chat
  child: Text('Hi', style: TextStyle(fontSize: chat.fontSize(14))),
);
```

### Advanced

- Register a `ChatTheme` in `ThemeData.extensions` to make it the app
  default; `ChatStyle` with no preset starts from it.
- `InboxView(theme: ...)` and `ChatRoomView(theme: ...)` style one view
  only (still scaled by the `ChatStyle` above it).

See the [customization cookbook](doc/customization.md) for many recipes.

## Builders, text and custom messages

```dart
ChatRoomView(
  controller: room,
  strings: const ChatStrings(typeMessage: 'Écrire un message', send: 'Envoyer'),
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

- **Builders**: `ChatBuilders` (room) and `InboxBuilders` (inbox). Each
  builder receives the default widget, so wrapping is one line.
- **Custom messages**: one builder per type (as many as you want, see
  below), and `bubbledCustomTypes` to draw them inside the normal bubble.
- **Text**: every string is in `ChatStrings`, English by default. Fill it
  from slang, intl or any localization tool. The example app is translated
  with slang into French and Arabic (right to left), with a language
  button; copy `example/lib/i18n/`. Dates follow `MaterialApp.locale`. See
  [Text and translation](doc/customization.md#text-and-translation).
- **Formats**: `ChatFormatters` for times, dates, durations and sizes.
- **Behavior**: `ChatConfig` for page sizes, grouping, reactions,
  auto-download and limits.

### Several custom message types

`customBuilders` is a map: **add one entry per type**, as many as you
need. The key is the `customType` you send, the value draws it:

```dart
ChatRoomView(
  controller: room,
  builders: ChatBuilders(
    customBuilders: {
      'offer': (context, m) => OfferCard(message: m),
      'location': (context, m) => LocationCard(message: m),
      'order': (context, m) => OrderCard(message: m),
    },
    // These are drawn inside the normal bubble; the others stand alone.
    bubbledCustomTypes: const {'location', 'order'},
  ),
  // Buttons in the attach sheet that send them.
  extraAttachmentOptions: [
    AttachmentOption(
      icon: Icons.local_offer_outlined,
      label: 'Offer',
      onSelected: () => room.sendCustom('offer', {'price': 120, 'item': 'Sofa'}),
    ),
    AttachmentOption(
      icon: Icons.place_outlined,
      label: 'Location',
      onSelected: () => room.sendCustom('location', {'lat': 36.75, 'lng': 3.06}),
    ),
  ],
)
```

Inside a builder, `m.message` is a `CustomMessage`; read what you sent from
its `data`:

```dart
class LocationCard extends StatelessWidget {
  const LocationCard({required this.message, super.key});

  final MessageContext message;

  @override
  Widget build(BuildContext context) {
    final data = (message.message as CustomMessage).data;
    return ListTile(
      leading: const Icon(Icons.place),
      title: Text('${data['lat']}, ${data['lng']}'),
      subtitle: Text(message.isMine ? 'You shared a location' : 'Location'),
    );
  }
}
```

Give each type a one-line text for the inbox and reply previews:

```dart
ChatStrings(
  customPreview: (type, data) => switch (type) {
    'offer' => 'Offer: ${data['item']}',
    'location' => 'Location',
    'order' => 'Order #${data['id']}',
    _ => null, // falls back to strings.unsupportedMessage
  },
)
```

Many types, or types decided at runtime? Use `customBuilder` as a catch-all
for every type that is not in the map (return `null` for the "unsupported"
view):

```dart
ChatBuilders(
  customBuilders: {'offer': (context, m) => OfferCard(message: m)},
  customBuilder: (context, m) {
    final data = (m.message as CustomMessage).data;
    return data['card'] is Map ? GenericCard(data['card']! as Map) : null;
  },
)
```

## Example app

[`example/`](example) is a complete app on a fake in-memory backend (no
accounts or keys): inbox, direct and group rooms, a 5 000-message room,
custom offer and booking messages, a business profile with staff, an
offline switch, and a live style sheet with every `ChatStyle` option,
presets, zoom and a flutter_scale_kit switch.

```bash
cd example
flutter run
```

## Screen size and theme kits

This part explains how the chat gets its size on each screen, and how to
use it with [flutter_scale_kit](https://pub.dev/packages/flutter_scale_kit),
[flutter_scale_theme_kit](https://pub.dev/packages/flutter_scale_theme_kit)
or any other package. The chat does not depend on any of them.

### The idea: one number for sizes, one for text

Every size in the chat (paddings, radii, avatars, icons) is a design
number, for example "bubble radius 18". To fit a screen, the chat
multiplies them all by **one factor**, and every font by **one text
factor**:

```dart
ChatStyle(
  scale: (context) => ChatScale(1.2),              // everything 20% bigger
  // scale: (context) => ChatScale(1.1, text: 1.3), // text grows more
  child: ...,
)
```

`scale` is a function, not a value: `ChatStyle` calls it again every time
the screen size changes (window resize, rotation, split screen), so the
chat always has the current size.

### With flutter_scale_kit

```dart
import 'package:flutter_scale_kit/flutter_scale_kit.dart';

void main() => runApp(
  ScaleKitBuilder(
    designWidth: 375,
    designHeight: 812,
    child: MaterialApp(
      builder: (context, child) => ChatKitScope(
        kit: kit,
        child: ChatStyle(
          scale: (context) => ChatScale(1.w, text: 1.sp),
          child: child!,
        ),
      ),
      home: const InboxPage(),
    ),
  ),
);
```

That one line is all. Why it is correct:

- **`1.w` is the factor.** In flutter_scale_kit, `14.w` is
  `14 × (width factor)`, and `1.w` is that factor. It is a plain
  multiplication with no rounding, so `14.w == 14 × 1.w` exactly. The chat
  does `18 × 1.w` for its bubble radius, which is the same as writing
  `18.w` yourself.
- **`1.sp` is the text factor.** `16.sp == 16 × 1.sp`, so a 16 message font
  becomes exactly `16.sp`, like your own `Text` widgets.
- **Rotation.** flutter_scale_kit swaps the design width and height when
  the device turns, and makes landscape phones a bit bigger (its
  landscape boost). `ScaleKitBuilder` updates first, then `ChatStyle`
  rebuilds (it listens to the screen size) and reads the new `1.w`, so the
  chat matches your widgets in portrait and landscape.
- **Height (`.h`).** The chat does not use `.h`. Chat content scrolls
  vertically, so heights come from the content; only widths, paddings,
  radii and fonts are scaled. Use `.h` in your own layouts as usual.
- **Radius.** flutter_scale_kit's `.r` uses its own formula. The chat
  scales radii like other sizes, so a chat radius of 18 equals `18.w`,
  not `18.r`.

This is tested, not guessed: `example/test/scale_kit_test.dart` runs the
real flutter_scale_kit and checks that `chat.size(14) == 14.w`,
`chat.fontSize(14) == 14.sp`, bubble radius `== 18.w`, avatar `== 52.w`
and message font `== 16.sp` on a phone, a rotated phone, a small phone and
a tablet, and after rotating and resizing.

**Rules to avoid double scaling:**

1. Give the chat design numbers: `bubbleRadius: 12`, `messageStyle:
   TextStyle(fontSize: 15)`. Not `12.w` or `15.sp`: the chat scales them.
2. Scale in one place. Use `ChatStyle(scale: ...)`, and don't also call
   `.scaled()` on a `ChatTheme` you register.
3. Keep your `ThemeData` text sizes as design sizes. flutter_scale_kit's
   `createResponsiveTextTheme` is safe on a text theme without written
   font sizes, like Flutter's default and the one flutter_scale_theme_kit
   builds (tested too). If you wrote already-scaled sizes into your text
   theme (`fontSize: 15.sp`), put the chat under a `Theme` with the
   unscaled text theme.
4. Inside chat builders, `8.w` and `context.chatTheme.size(8)` give the
   same number, so use whichever you like.

If you turn `ScaleKitBuilder`'s `enabled` on and off at runtime, add
`ScaleKitScope.watch(context);` as the first line of the `scale` function,
so the chat also rebuilds on that switch.

### With flutter_screenutil or another package

Any package with a "`1.w`"-style factor works the same way:

```dart
ScreenUtilInit(
  designSize: const Size(375, 812),
  builder: (context, child) => MaterialApp(
    builder: (context, child) => ChatStyle(
      scale: (context) => ChatScale(1.w, text: 1.sp),
      child: child!,
    ),
    home: const InboxPage(),
  ),
);
```

### Without a package

```dart
ChatStyle(scale: ChatScale.byScreen(), child: ...)          // by screen width
ChatStyle(scale: ChatScale.byScreen(designWidth: 390, max: 1.5), child: ...)
ChatStyle(scale: ChatScale.fixed(1.15), child: ...)         // always 15% bigger
```

`byScreen` uses the screen's shortest side, so the size stays the same when
the phone rotates.

**A zoom setting for users** multiplies with the screen scale:

```dart
scale: (context) => ChatScale(1.w, text: 1.sp) * ChatScale(settings.zoom),
```

### With flutter_scale_theme_kit (colors and tokens)

flutter_scale_theme_kit builds your `ThemeData` from design tokens. The
chat reads colors from `ThemeData`, so it **follows your theme and dark
mode with no extra code**:

```dart
ScaleKitBuilder(
  designWidth: 375,
  designHeight: 812,
  child: STThemeModeScope(
    builder: (context, mode) => MaterialApp(
      theme: appST.light,        // appST is your STTheme
      darkTheme: appST.dark,
      themeMode: mode.mode,
      builder: (context, child) => ChatKitScope(
        kit: kit,
        child: ChatStyle(
          scale: (context) => ChatScale(1.w, text: 1.sp),
          child: child!,
        ),
      ),
      home: const InboxPage(),
    ),
  ),
);
```

To use your tokens for exact chat parts, read them with `context.st` and
pass them to `ChatStyle`. Token radii are design numbers, exactly what the
chat wants:

```dart
class ChatArea extends StatelessWidget {
  const ChatArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final st = context.st; // light or dark, follows the mode
    return ChatStyle(
      bubbleRadius: st.radius.lgValue,
      tiles: ChatTiles.divided,
      customize: (chat) => chat.copyWith(
        outgoingBubble: chat.outgoingBubble.copyWith(color: st.primary),
        incomingBubble: chat.incomingBubble.copyWith(
          color: st.surface,
          border: BorderSide(color: st.border),
        ),
      ),
      scale: (context) => ChatScale(1.w, text: 1.sp),
      child: child,
    );
  }
}
```

If you register a `ChatTheme` in the theme instead, keep the theme kit's
extensions:
`appST.light.copyWith(extensions: [...appST.light.extensions.values, myChatTheme])`.

## Troubleshooting

Most problems come from the JSON. Run `ChatJsonCheck` on a real response
first ([how](doc/backend_json.md#check-your-json-chatjsoncheck)): it names
the field and the fix.

**Images or videos show as file cards.**
The attachment has no `mime_type` and its URL has no extension, inside a
`file` message (or a type the kit maps to file). Send `mime_type`, or use
the `image` / `video` message type: an extension-less URL in an image
message is shown as an image.

**Times are off by a few hours.**
Your dates have no time zone (`2026-09-30T12:00:00`), so each phone reads
them in its own zone. End them with `Z` or an offset (`+01:00`).

**Dates show in 1970, or thousands of years ahead.**
The value is not epoch seconds or milliseconds (both work): it's `0`, a
duration, microseconds or nanoseconds. Send milliseconds or ISO-8601.

**My message appears twice after sending.**
The server created a second message on a retry, or doesn't return
`local_id`. Make send idempotent on `localId` and echo `local_id` in the
response and in realtime events
([Sending](doc/backend_json.md#sending)).

**A room doesn't move to the top on a new message.**
The inbox sorts by `updated_at`. Bump it on every new message, and emit
`RoomChanged(Updated(room))` from `events()` (the inbox stream, `roomId ==
null`), or use `PollingRealtime`.

**Nothing updates live.**
`events()` returns an empty stream or never emits for this room. Emit
`MessageChanged` for room streams and `RoomChanged` for the inbox, or
plug in `PollingRealtime`. After being offline, call
`kit.setOnline(online: true)`.

**`FormatException: Message "...": missing "room_id"`.**
Your messages endpoint leaves the room out. Pass it:
`Message.fromJson(json, roomId: roomId)`. Other "missing" errors name the
`ChatJsonKeys` field to set.

**Names are empty and avatars are blank.**
The kit has no `ChatUser` for those ids. Return `users` with your pages,
or pass a `ChatUserResolver` ([Names and avatars](#names-and-avatars)).

**Avatars and images are blank on the web only.**
The image host doesn't send CORS headers, so the browser blocks the
pixels. Serve them with `Access-Control-Allow-Origin` (Firebase Storage
needs a CORS config on the bucket), or through your own domain.

**The chat stays empty or loading on the web.**
`sqlite3.wasm` or `drift_worker.js` is missing from `web/`. Run
`dart run flutter_chat_pro:web_setup`.

**No attach or mic button.**
`ChatKit` has no `uploader`. Pass a `ChatUploader`
([The classes you write](#3-the-classes-you-write)).

**After the login token expires, every queued message turns red.**
Your source throws something other than `AuthFailure` on a 401. Throw
`AuthFailure(AuthReason.expired)`: the kit then pauses sending (messages
stay "sending") and calls `onAuthExpired`. Refresh the session there and
resume:

```dart
late final ChatKit kit;
kit = ChatKit(
  currentUserId: uid,
  source: source,
  onAuthExpired: () async {
    await auth.refreshSession();
    await kit.retryPending();
  },
);
```

**Retrying a photo on the web says the file is no longer available.**
It was picked before the page reloaded; browsers forget picked files on
reload. Delete the message and pick the file again.

## Let your AI agent build it

This package ships an [Agent Skill](https://agentskills.io) that teaches
your AI agent (Cursor, Claude Code, GitHub Copilot, Codex, Windsurf, Gemini
CLI, ...) how to use the kit correctly: the `ChatSource` rules, controller
lifetimes, `ChatStyle`, scaling without double scaling, and the backend
guides.

```bash
npx skills add fodilfliti/flutter_chat_kit
```

Or install the whole Lemsa family (chat, scale kit, theme kit):

```bash
npx skills add fodilfliti/lemsa-skills
```

Then ask your agent, for example:

- *"Add a chat to this app with flutter_chat_pro. Backend: Firestore.
  Inbox with Chats and Groups tabs, WhatsApp style."*
- *"Write a ChatSource for our REST API (docs in `api.md`) with realtime
  from our WebSocket at `wss://...`."*
- *"Make the chat follow flutter_scale_kit and our theme kit tokens."*
- *"Add a custom 'order' message with a card and a Pay button."*

## Links

- [Backend JSON](doc/backend_json.md)
- [Plug in an existing API](doc/adapters/your_api.md)
- [Customization cookbook](doc/customization.md)
- [Push notifications](doc/push.md)
- [GitHub](https://github.com/fodilfliti/flutter_chat_kit)
- [Issues](https://github.com/fodilfliti/flutter_chat_kit/issues)
- [Lemsa skills](https://github.com/fodilfliti/lemsa-skills)
