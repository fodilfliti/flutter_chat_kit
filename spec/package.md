# flutter_chat_pro

Backend-agnostic chat kit. The app implements a small backend contract; the kit owns models, cache, sync, outbox, controllers, and a fully customizable chat room and inbox UI. Replaces the hand-built chats in valizex (Firebase, sqflite, `Map` messages) and lightnessword (Supabase, ReaxDB blob cache).

## Owns

- Typed immutable models: sealed `Message` (`TextMessage`, `ImageMessage`, `VideoMessage`, `AudioMessage`, `FileMessage`, `SystemMessage`, `CustomMessage`), `Attachment`, `ChatRoom`, `RoomMember`, `ChatUser`, `MessageStatus`, cursors, `ChatPage`, `ChatEvent`, JSON codec
- Contracts the app implements: `ChatSource`, `ChatUploader`, `ChatUserResolver`
- Built-in Drift (SQLite) cache, one database per user, background isolate
- `ChatRepository`: cache-first reads, per-room gap fill, keyset paging, jump-around window, realtime event application, retention
- `Outbox`: optimistic send, upload progress, retry with backoff, failed state, reconciliation by `localId`
- `ChatKit` root + `ChatKitScope`; `InboxController`, `ChatRoomController`, `ComposerController`, `VoiceRecorderController`, `AudioPlayerHub`
- `ChatTheme`, `ChatConfig`, `ChatStrings`, `ChatFormatters`, `ChatBuilders`, `InboxBuilders`, `MessageContext`
- Widgets: `ChatRoomView`, `ChatAppBar`, `ChatMessageList`, `ChatComposer`, message widgets, media viewer, `InboxView`, `RoomTile`

## Does not own

| Concern | Where |
| --- | --- |
| Backend calls (Firestore, Supabase, REST, WebSocket) | app `ChatSource` |
| File storage upload | app `ChatUploader` |
| Push notifications, FCM tokens | app |
| Connectivity detection | app (feeds `ChatKit.setOnline`) |
| Riverpod providers | app (wraps `ChatKit` and controllers) |
| Translations | app (passes `ChatStrings`) |
| Navigation | app (`onRoomTap`, `onAvatarTap` callbacks) |

## Public surface (target for 0.1.0)

| Export | Contents |
| --- | --- |
| `flutter_chat_pro.dart` | Everything below; the only barrel |

```dart
abstract interface class ChatSource {
  Future<ChatPage<ChatRoom>> fetchRooms({RoomCursor? after, int limit = 20, String? search});
  Future<ChatPage<Message>> fetchMessages(String roomId,
      {MessageCursor? before, MessageCursor? after, int limit = 30});
  Future<ChatPage<Message>> fetchAround(String roomId, String messageId, {int limit = 30});
  Stream<ChatEvent> events({String? roomId});
  Future<Message> send(Message pending);          // idempotent on localId
  Future<Message> edit(Message message);
  Future<void> delete(String roomId, String messageId);
  Future<void> markRead(String roomId, MessageCursor upTo);
  Future<void> setTyping(String roomId, {required bool typing});   // optional
  Future<void> react(String roomId, String messageId, String emoji, {required bool add}); // optional
}

final kit = ChatKit(
  currentUserId: uid,
  source: MyFirestoreChatSource(),
  uploader: MyStorageUploader(),
  users: MyUserResolver(),
  config: const ChatConfig(),
);
await kit.open();                 // opens chat_kit_<uid>.sqlite

ChatKitScope(kit: kit, child: InboxView(onRoomTap: (room) => ...));
ChatRoomView(controller: kit.room(roomId), builders: ChatBuilders(...));

await kit.clearUserData();        // on sign-out
```

## Layers

| Layer | Path | Role |
| --- | --- | --- |
| Barrel | `lib/flutter_chat_pro.dart` | Only public export |
| Models | `lib/src/models/` | Immutable data + JSON |
| Source | `lib/src/source/` | Contracts the app implements |
| Cache | `lib/src/cache/` | `ChatCache` interface + Drift implementation |
| Sync | `lib/src/sync/` | Repository, outbox, retry, per-room sync state |
| Controllers | `lib/src/controllers/` | `ChatKit` root and screen controllers |
| Config | `lib/src/config/` | Theme, config, strings, formatters |
| Builders | `lib/src/builders/` | Builder typedefs, `MessageContext` |
| Widgets | `lib/src/widgets/{room,messages,composer,media,inbox}/` | Default UI |

## Depends on

`lemsa_core_kit`, `drift`, `drift_flutter`, `path_provider`, `super_sliver_list`, `uuid`, `intl`, `collection`, `cached_network_image`, `image_picker`, `file_picker`, `record`, `audioplayers`, `video_player`. Dev: `drift_dev`, `build_runner`, `very_good_analysis`.

## Must not depend on

`firebase_*`, `cloud_firestore`, `supabase_flutter`, `dio`, `flutter_riverpod`, `hooks_riverpod`, `riverpod_annotation`, `slang`, `easy_localization`, `flutter_page_kit`, `flutter_scale_kit`, `flutter_scale_theme_kit`.

## Platform setup the app must do

- Web: copy `sqlite3.wasm` and `drift_worker.js` into `web/` (Drift web setup).
- Permissions: microphone (`record`), camera and photos (`image_picker`) in `Info.plist` / `AndroidManifest.xml`.
