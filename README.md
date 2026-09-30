# flutter_chat_kit

[![pub package](https://img.shields.io/pub/v/flutter_chat_kit.svg)](https://pub.dev/packages/flutter_chat_kit)

A complete chat for Flutter that works with **any backend**. You write one
class that talks to your server (Firebase, Supabase, REST, WebSocket, ...).
The kit does everything else: the inbox and chat room screens, an offline
cache, a send queue, media, voice messages, read receipts, and styling.

**Platforms:** Android, iOS, Linux, macOS, Web, Windows
**Requires:** Flutter `>=3.44.0`

> **Using an AI agent?** Run `npx skills add fodilfliti/flutter_chat_kit`,
> then ask: *"Add a chat to this app with flutter_chat_kit."* See
> [Let your AI agent build it](#let-your-ai-agent-build-it).

## Contents

- [Features](#features)
- [Install](#install)
- [Quick start: a working chat in 3 steps](#quick-start-a-working-chat-in-3-steps)
- [How the pieces fit](#how-the-pieces-fit)
- [Connect your backend](#connect-your-backend)
- [Style the chat](#style-the-chat)
- [Builders, text and custom messages](#builders-text-and-custom-messages)
- [Platform setup](#platform-setup)
- [Example app](#example-app)
- [Screen size and theme kits](#screen-size-and-theme-kits)
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
- **Smooth at any size**: the message list never jumps when pages or new
  messages arrive, and can jump to any old message.
- **Easy to style**: one `ChatStyle` widget with presets (WhatsApp,
  Telegram, ...), simple options and screen scaling that works with any
  scale package.

## Install

```yaml
dependencies:
  flutter_chat_kit: ^0.1.0
```

```dart
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
```

## Quick start: a working chat in 3 steps

### 1. Create the kit and put it above your app

`ChatKit` is the chat engine for the signed-in user. Create it after login
and open it:

```dart
final kit = ChatKit(
  currentUserId: user.id,
  source: MyChatSource(),     // your backend, see "Connect your backend"
  uploader: MyUploader(),     // optional: enables photos, files and voice
  users: MyUserResolver(),    // optional: names and avatars
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

Implement `ChatSource`. Mix in `ChatSourceDefaults` to skip the optional
parts (typing, reactions, search, ...):

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

Four rules keep the cache correct:

- Throw `AppFailure`s from `lemsa_core_kit`, never vendor exceptions.
  `NetworkFailure` and `TimeoutFailure` make the send queue retry.
- Message pages are **newest first**. Cursors are exclusive bounds on
  `(createdAt, id)`.
- `send` must be **idempotent on `localId`** (use it as the document id or a
  unique key), so a retry never creates a duplicate.
- `events` also delivers your own messages; the kit removes duplicates.

`Message.fromJson` / `toJson` and `ChatRoom.fromJson` read the usual JSON
shape; pass `ChatJsonKeys(...)` when your field names differ. Call
`kit.setOnline(online: ...)` from your connectivity check: going online
fills gaps, refreshes lists and sends queued messages.

Step-by-step guides with schema, realtime and uploads:
[Firestore](doc/adapters/firestore.md) ·
[Supabase](doc/adapters/supabase.md) ·
[REST + WebSocket](doc/adapters/rest_websocket.md) ·
[Several lists and mixed backends](doc/adapters/mixing.md) ·
[Profiles and business accounts](doc/adapters/profiles.md)

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

**Presets:** `ChatPreset.classic`, `whatsApp`, `telegram`, `minimal`,
`cards` (all in `ChatPreset.values`, handy for a settings screen). A preset
only gives defaults: any option you pass wins.

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
- **Custom messages**: one builder per type, and `bubbledCustomTypes` to
  draw them inside the normal bubble.
- **Text**: every string is in `ChatStrings`, English by default. Fill it
  from slang, intl or any localization tool.
- **Formats**: `ChatFormatters` for times, dates, durations and sizes.
- **Behavior**: `ChatConfig` for page sizes, grouping, reactions,
  auto-download and limits.

## Platform setup

**Web.** The SQLite cache runs in a web worker. Copy two files into your
app's `web/` folder:

- `sqlite3.wasm` from the
  [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases)
  (the version matching `sqlite3` in your `pubspec.lock`);
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

**macOS**: the same microphone and camera keys in `Info.plist`, and these
entitlements in both `DebugProfile.entitlements` and
`Release.entitlements`: `com.apple.security.network.client`,
`com.apple.security.device.audio-input`,
`com.apple.security.device.camera`,
`com.apple.security.files.user-selected.read-write`.

**Linux**: voice playback uses GStreamer
(`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`).
**Windows and Linux**: `video_player` has no official desktop
implementation; add one (for example `video_player_win` or `fvp`) for
in-app video there.

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

- *"Add a chat to this app with flutter_chat_kit. Backend: Firestore.
  Inbox with Chats and Groups tabs, WhatsApp style."*
- *"Write a ChatSource for our REST API (docs in `api.md`) with realtime
  from our WebSocket at `wss://...`."*
- *"Make the chat follow flutter_scale_kit and our theme kit tokens."*
- *"Add a custom 'order' message with a card and a Pay button."*

## Links

- [Customization cookbook](doc/customization.md)
- [GitHub](https://github.com/fodilfliti/flutter_chat_kit)
- [Issues](https://github.com/fodilfliti/flutter_chat_kit/issues)
- [Lemsa skills](https://github.com/fodilfliti/lemsa-skills)
