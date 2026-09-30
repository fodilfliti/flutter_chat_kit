---
name: flutter-chat-kit
description: >
  Use flutter_chat_kit to build chat screens: a chat room page, an inbox
  (conversation list), direct and group chats, media and voice messages,
  replies, reactions, read receipts, offline cache and outbox. Activate when
  implementing a ChatSource for Firebase, Supabase or REST, styling the chat
  (ChatStyle, presets like WhatsApp or Telegram, bubbles, inbox rows),
  scaling it with flutter_scale_kit, flutter_screenutil or
  flutter_scale_theme_kit, adding custom message types (offers, cards),
  adding app bar actions to a chat page, or letting one account chat as
  several profiles (personal and business pages answered by staff) — not for
  backend SDK code inside the kit, Riverpod inside the kit, or localizing
  inside the kit.
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
| `InboxView` / `ChatRoomView` | kit | complete screens; `InboxView(roomBuilder:)` pushes the room, or `onRoomTap` for app navigation |
| `ChatStyle` | kit | look and screen scale of every chat widget below it; builds the `ChatTheme` |

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
    body: ChatStyle(              // optional; see "Style and scale"
      preset: ChatPreset.whatsApp,
      child: InboxView(
        controller: _inbox,
        strings: chatStrings,
        // Pushes the room with ChatStyle.push: the room keeps the style.
        roomBuilder: (context, room) => RoomPage(roomId: room.id),
      ),
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

With a router (auto_route, go_router), use `onRoomTap` and keep the style
on the pushed page. Capture it before navigating:

```dart
onRoomTap: (room) {
  final keepStyle = ChatStyle.carry(context);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => keepStyle(RoomPage(roomId: room.id)),
  ));
},
```

A route page built by the router outside the style gets it by wrapping its
body in the same `ChatStyle` (put the options in one app widget, for example
`ChatArea`, and use it in both places), or by a `ChatStyle` in
`MaterialApp.builder` that covers every route.

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
`doc/adapters/rest_websocket.md`, `doc/adapters/mixing.md`,
`doc/adapters/profiles.md`.

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

## Profiles and business accounts

One account, several chat identities (personal profile, business pages):
`ChatKit.currentUserId` is the **profile** id; `agentId` is the staff
account acting for it, stamped on sent messages as `Message.sentBy`.

```dart
final switcher = ChatProfileSwitcher(
  profiles: [
    ChatProfile(id: uid, name: 'Ali'),
    ChatProfile(id: shopId, name: 'Shop', kind: ChatProfileKind.business, agentId: uid),
  ],
  createKit: (p) => ChatKit(          // a new kit on every call
    currentUserId: p.id,
    agentId: p.agentId,
    source: MyChatSource(actingAs: p.id),
  ),
);
await switcher.open();
MaterialApp(builder: (context, child) =>
    ChatProfileScope(switcher: switcher, child: child!));
// Inbox app bar: const ChatProfileMenuButton()
// Code: await switcher.switchTo(id); setProfiles([...]) with unreadCount
// Sign-out: await switcher.clearAllUserData(); switcher.dispose();
```

- Only the active profile's kit is open (own database and media folder);
  `ChatProfileScope` rebuilds the chat tree on each switch, so pages must
  get the kit from `context.chatKit`.
- Staff see a colleague's name above their messages
  (`ChatConfig.showSentBy`) and "Sara: ..." in previews; they can edit only
  their own (`MessageContext.isSentByMe`). Customers see the business only.
- Backend: every request acts as a profile; the server checks the account
  may act as it and sets `sent_by` itself (see `doc/adapters/profiles.md`).
- Unread counts of inactive profiles come from the backend
  (`ChatProfile.unreadCount`).

## Sending from code

```dart
await room.sendText('Hi', replyToId: replyTo?.id);
await room.sendCustom('offer', {'title': 'Bike', 'amount': 120});
```

The composer inside `ChatRoomView` handles text, media, voice, reply and
edit. Messages appear immediately as pending, then move to sent, delivered
and read; failed ones show a retry action.

## Style and scale

Default: no styling code. The chat follows the app's `ThemeData` colors,
fonts and dark mode. To change it, wrap the chat part in `ChatStyle`:

```dart
ChatStyle(
  preset: ChatPreset.whatsApp,   // classic, whatsApp, telegram, minimal, cards
  seedColor: Colors.teal,        // chat colors from one color, light and dark
  bubbleRadius: 12,              // design numbers, never 12.w
  bubbleShadows: true,
  bubbleBorder: false,
  messageStyle: const TextStyle(fontSize: 15),
  fontFamily: 'Inter',
  tiles: ChatTiles.divided,      // plain, divided, cards
  tileRadius: 20,
  squareAvatars: true,
  wallpaper: const BoxDecoration(color: Color(0xFFEFEAE2)),
  customize: (theme) => theme.copyWith(
    incomingBubble: theme.incomingBubble.copyWith(color: Colors.white),
  ),
  scale: (context) => ChatScale(1.w, text: 1.sp),
  child: ...,
)
```

- Order: preset (or registered `ChatTheme`, or app colors) → options →
  `customize` → `scale`. `customize` is for parts without an option.
- Where: around the inbox page (chat part only), in `MaterialApp.builder`
  (all chats), or nested for one screen; a nested `ChatStyle` changes only
  what it passes and never scales twice.
- Rooms from `roomBuilder`, `ChatStyle.push(context, builder)` and pages
  wrapped with `ChatStyle.carry(context)` keep the style and follow its
  changes. Sheets and dialogs keep it on their own.
- App widgets read it with `context.chatTheme`; sizes with
  `context.chatTheme.size(8)`, fonts with `.fontSize(14)`.
- Custom presets: create once as a top-level `final ChatPreset(...)`.

Scale (`scale:` is a function; `ChatStyle` re-runs it on resize and
rotation):

| App uses | `scale:` |
| --- | --- |
| flutter_scale_kit (`ScaleKitBuilder` above `MaterialApp`) | `(context) => ChatScale(1.w, text: 1.sp)` |
| flutter_screenutil (`ScreenUtilInit`) | `(context) => ChatScale(1.w, text: 1.sp)` |
| nothing | `ChatScale.byScreen()` (shortest side / 375, clamped 0.85–1.3) |
| fixed zoom | `ChatScale.fixed(1.2, text: 1.1)` |
| user zoom on top | `(context) => ChatScale(1.w, text: 1.sp) * ChatScale(zoom)` |

- `14.w == 14 × 1.w` (no rounding), so every chat size equals `.w` on the
  design number; fonts equal `.sp`. Proven by
  `example/test/scale_kit_test.dart` on phones, landscape and tablets.
- The chat does not use `.h`; radii follow `.w`, not `.r`.
- Never double scale: no `.w` / `.sp` in `ChatStyle` options or
  `customize`; no `.scaled()` on a registered `ChatTheme` when `ChatStyle`
  scales; keep `ThemeData` text sizes unscaled (`createResponsiveTextTheme`
  on a text theme without written sizes, like flutter_scale_theme_kit's,
  is fine).
- If `ScaleKitBuilder.enabled` toggles at runtime, start the scale function
  with `ScaleKitScope.watch(context);`.

flutter_scale_theme_kit: pass `appST.light` / `appST.dark` to `MaterialApp`
as usual; the chat follows its colors and mode. To use tokens, read
`context.st` in the widget that builds `ChatStyle`:
`bubbleRadius: st.radius.lgValue` (design px), and in `customize` set
`outgoingBubble.color: st.primary`, `incomingBubble.color: st.surface`,
`border: BorderSide(color: st.border)`. When registering a `ChatTheme`,
keep the kit's extensions: `extensions: [...appST.light.extensions.values,
chatTheme]`.

## Customizing

```dart
ChatRoomView(
  controller: room,
  theme: myChatTheme, // one screen only; still scaled by ChatStyle above
  builders: ChatBuilders(
    bubbleBuilder: (context, m, defaultChild) => defaultChild,
    customBuilders: {'offer': (context, m) => OfferCard(message: m)},
    // Variants of one type, picked from the data; null = unsupported.
    customBuilder: (context, m) => switch ((m.message as CustomMessage).data['variant']) {
      'quote' => QuoteCard(message: m),
      _ => null,
    },
    // Drawn inside the regular bubble with time and ticks.
    bubbledCustomTypes: const {'booking'},
    messageActions: (context, m, defaults) => [...defaults, report(m)],
    appBarActions: (context, room) => [infoButton],
    composerBuilder: (context, defaultChild) => defaultChild,
  ),
  extraAttachmentOptions: [
    AttachmentOption(icon: Icons.place, label: t.location, onSelected: share),
  ],
);
```

- Prefer `ChatStyle`. Otherwise register `ChatTheme` in
  `ThemeData.extensions` (derive it with `ChatTheme.fallback(colorScheme)`),
  or pass `theme:` for one screen. It is grouped: `outgoingBubble` / `incomingBubble` (`ChatBubbleStyle`:
  color or gradient, text, radius, border, shadows), `messageList`
  (spacing, avatars, `background`), `status`, `dateSeparator`,
  `systemMessage`, `unreadDivider`, `reactions`, `replyPreview`, `media`,
  `composer`, `appBar`, `avatar` (`radius` null = circle), `roomTile`
  (`ChatRoomTileStyle.plain` / `.divided` / `.card`, any `shape`) and
  `badge`. Change a group with `copyWith` on it, then on the theme.
- Helpers: `withMessageText(style)`, `mapBubbles((b) => ...)`,
  `mapText((s) => ...)`. `scaled(factor, textFactor:)` resizes a theme you
  build yourself; call it last, and not when `ChatStyle` has a `scale`.
- Custom types: `customBuilders[type]` first, then the `customBuilder`
  resolver, then "unsupported". `bubbledCustomTypes` keeps the bubble;
  inside it use `theme.bubble(isMine: m.isMine).textStyle` for colors.
- Every builder gets the default widget: wrap it instead of rebuilding it.
- `MessageContext`: `message`, `author`, `sender` (staff in `sentBy`),
  `isMine`, `isSentByMe`, `isSentByColleague`, `groupPosition`, `status`,
  `seenBy`, `repliedTo`, `isSelected`, `room`, `uploadProgress`.
- `RoomContext` (inbox): `room`, `peer`, `lastMessageAuthor`,
  `lastMessageSender`, `presence`, `typingNames`.
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
- Do not create a second `ChatKit` for the same user; share one. For
  several profiles use `ChatProfileSwitcher`, not kits open side by side.
- Do not client-filter or reorder messages; the kit keeps order and paging.
- Do not show failures' text from the kit; map `AppFailure` to your own
  messages.
- Do not pass scaled values (`12.w`, `15.sp`) to `ChatStyle` or a
  `ChatTheme`; give design numbers and one `scale:`.
- Do not add a scale package to make the chat scale; the app passes its
  factor through `ChatScale`.

## Where things go

| Concern | Where |
| --- | --- |
| Firebase / Supabase / REST calls | app `ChatSource` implementation |
| File storage upload | app `ChatUploader` implementation |
| User names and avatars | app `ChatUserResolver` |
| Account's chat profiles and their unread counts | app / backend, fed to `ChatProfileSwitcher` |
| Riverpod providers | app (wrap `ChatKit` / controllers) |
| Translated strings | app, via `ChatStrings` |
| Chat look and screen scale | app, one `ChatStyle` (or an app widget wrapping it) |
| Push notifications | app (`switcher.switchTo(profileId)` if needed, then open the room) |
