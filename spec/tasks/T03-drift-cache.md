# T03 — Drift cache

## Goal

The built-in SQLite cache: typed tables, reactive queries, one database per user, off the UI isolate. The UI will read only from here.

## Read first

- [../invariants.md](../invariants.md) (Cache and sync), [../decisions.md](../decisions.md) D2, D5
- Drift docs: `drift_flutter` `driftDatabase(name:, web:, native:)`, `watch()`, migrations
- Family reference: `lemsa_packages/flutter_data_kit/packages/flutter_data_kit_drift/` (table and `deleteUserData` style)

## Depends on

T02.

## Deliverables

```text
lib/src/cache/chat_cache.dart                 abstract interface ChatCache
lib/src/cache/drift/tables.dart               Rooms, Members, Users, Messages, Outbox, RoomSyncStates, Drafts
lib/src/cache/drift/chat_database.dart        @DriftDatabase + migrations (schemaVersion 1)
lib/src/cache/drift/chat_database.g.dart      generated, committed
lib/src/cache/drift/converters.dart           JSON / enum / DateTime type converters
lib/src/cache/drift/open_chat_database.dart   driftDatabase(name: 'chat_kit_<userId>')
lib/src/cache/drift_chat_cache.dart           DriftChatCache implements ChatCache
lib/src/sync/room_sync_state.dart             RoomSyncState model
test/cache/drift_chat_cache_test.dart         NativeDatabase.memory()
```

## Schema

| Table | Columns (key ones) | Indexes |
| --- | --- | --- |
| `rooms` | `id` PK, `type`, `title`, `avatar_url`, `last_message_json`, `unread_count`, `updated_at`, `pinned`, `muted`, `metadata_json` | `(pinned DESC, updated_at DESC, id)` |
| `members` | `room_id`, `user_id`, `role`, `last_read_at`, `last_delivered_at` | PK `(room_id, user_id)` |
| `users` | `id` PK, `name`, `avatar_url`, `metadata_json`, `fetched_at` | — |
| `messages` | `local_id` PK, `id` UNIQUE, `room_id`, `author_id`, `type`, `created_at`, `edited_at`, `deleted_at`, `status`, `reply_to_id`, `body_json` (subtype fields), `reactions_json`, `metadata_json` | `(room_id, created_at DESC, id DESC)` |
| `outbox` | `local_id` PK, `room_id`, `op` (send/edit/delete/react), `payload_json`, `attempts`, `next_attempt_at`, `last_error` | `(next_attempt_at)` |
| `room_sync_state` | `room_id` PK, `newest_created_at`, `newest_id`, `oldest_created_at`, `oldest_id`, `has_more_older`, `synced_at` | — |
| `drafts` | `room_id` PK, `text`, `reply_to_id`, `updated_at` | — |

## Public API

```dart
abstract interface class ChatCache {
  Future<void> open(String userId);
  Future<void> close();
  Future<void> clear();                               // clearUserData

  Stream<List<ChatRoom>> watchRooms({String? search});
  Stream<List<Message>> watchMessages(String roomId, {required int limit, MessageCursor? anchorAfter}); // newest first
  Stream<List<RoomMember>> watchMembers(String roomId);
  Future<List<Message>> messagesBefore(String roomId, MessageCursor cursor, int limit);
  Future<List<Message>> messagesAfter(String roomId, MessageCursor cursor, int limit);
  Future<Message?> messageByAnyId(String idOrLocalId);

  Future<void> upsertRooms(List<ChatRoom> rooms);
  Future<void> deleteRoom(String roomId);
  Future<void> upsertMessages(List<Message> messages); // match on local_id, else id; one transaction
  Future<void> deleteMessage(String idOrLocalId);
  Future<void> upsertMembers(String roomId, List<RoomMember> members);
  Future<void> upsertUsers(List<ChatUser> users);
  Future<Map<String, ChatUser>> users(Set<String> ids);

  Future<RoomSyncState?> syncState(String roomId);
  Future<void> saveSyncState(RoomSyncState state);

  Future<void> enqueue(OutboxEntry entry);            // T05 uses these
  Future<List<OutboxEntry>> dueOutbox(DateTime now);
  Future<void> updateOutbox(OutboxEntry entry);
  Future<void> removeOutbox(String localId);

  Future<String?> draft(String roomId);
  Future<void> saveDraft(String roomId, String? text, {String? replyToId});

  Future<void> trim(String roomId, {required int keep}); // retention
}
```

Web: `driftDatabase(web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')))`. Document the files the app must copy in `package.md` (already listed).

### As built

- All timestamps are `INTEGER` UTC **microseconds**. Drift's default `DateTime` storage is whole seconds, which would break keyset cursors.
- `messages.body_json` holds only the subtype fields, in the kit's default `MessageCodec` format, whatever `ChatJsonKeys` the app uses. The base fields are real columns and are the source of truth on read.
- `upsertMessages` keeps the row whose `local_id` matches and deletes a duplicate row holding the server `id`, so a pending row never ends up beside its echo.
- Read and delivered pointers are monotonic in the cache (the maximum of stored and incoming). `upsertRooms` replaces a room's member set only when `members` is non-empty.
- `outbox` is keyed by `key` (for example `send:<localId>`), with `local_id` as a column, so one message can have several pending writes (edit, react). `OutboxEntry` / `OutboxOp` landed here for that reason.
- Added to the interface: `isOpen`, `watchRoom`, `staleUsers(ids, olderThan:)`, and `outbox()`. `draft` returns `ChatDraft{text, replyToId}`. The draft column is `body` (`text` clashes with Drift's column builder).
- `DriftChatCache(executorFactory:, clock:)`. The default factory `openChatDatabase` uses `driftDatabase(name: chatDatabaseName(userId))` with the web files above. `chatDatabaseName` sanitizes ids and adds a djb2 hash when needed.
- `ChatKit(cache:)` defaults to `DriftChatCache()`. `clearUserData()` works whether or not the kit is open.
- Changed in T04: the anchored `watchMessages(limit:, anchorAfter:)` became `watchMessages(roomId, {from, to, limit})`, plus a one-shot `messages(...)` with the same bounds. Both bounds are inclusive, results are newest first, and `limit` keeps the newest. `updatePointers(roomId, userId, {readAt, deliveredAt})` was added for receipts; it keeps the member's role.

## Done when

- [x] `build_runner` output committed; analyze clean (generated files excluded from lints)
- [x] Tests on `NativeDatabase.memory()`: upsert by `local_id` then by server `id` (reconciliation keeps one row), ordering by `(created_at DESC, id DESC)`, `messagesBefore` keyset correctness with equal timestamps, `watchMessages` emits on insert, `trim`, `clear`
- [x] Opening two different user ids uses two files
- [x] `ChatKit.open()` opens the cache; `clearUserData()` clears it

## Do not

- Store a room's messages as one JSON blob
- Close the database from any widget or controller other than `ChatKit`
- Add `sqflite` (Drift covers all platforms)
