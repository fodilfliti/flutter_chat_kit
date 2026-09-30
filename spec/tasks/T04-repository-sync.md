# T04 — ChatRepository (sync)

## Goal

The only component that talks to `ChatSource` for reads and realtime. It fills the cache; the UI watches the cache.

## Read first

- [../invariants.md](../invariants.md) (Data, Cache and sync), [../decisions.md](../decisions.md) D5
- Bugs to avoid: valizex `conversation_helpers.dart` `syncConversationMessages` (global cursor), lightnessword `dmChat_state_provider.dart` `getAllMessagesFromSupabase` (growing limit, realtime not cached)

## Depends on

T03.

## Deliverables

```text
lib/src/sync/chat_repository.dart
lib/src/sync/room_window.dart        latest vs detached window state
test/sync/chat_repository_test.dart  FakeChatSource + in-memory cache
```

## Public API

```dart
class ChatRepository {
  ChatRepository({required ChatSource source, required ChatCache cache, required ChatUserResolver? users, required ChatConfig config});

  // Inbox
  Stream<List<ChatRoom>> watchRooms({String? search});
  Future<bool> refreshRooms();                 // first page; returns hasMore
  Future<bool> loadMoreRooms();

  // Room lifecycle
  Future<void> openRoom(String roomId);        // gap fill + subscribe events(roomId)
  Future<void> closeRoom(String roomId);       // cancel subscription
  Stream<List<Message>> watchMessages(String roomId, RoomWindow window);
  Future<bool> loadOlder(String roomId);       // cache first, then source; returns hasMoreOlder
  Future<bool> loadNewer(String roomId);       // detached window only
  Future<RoomWindow> jumpTo(String roomId, String messageId); // cache hit or fetchAround
  Future<void> resync();                       // reconnect: gap fill every open room

  // Users
  Future<Map<String, ChatUser>> users(Set<String> ids); // cache, then resolver (batched, TTL from config)
}
```

## Behaviour

1. `openRoom`: read `room_sync_state`. If present, `fetchMessages(after: newest)` in pages until `hasMore == false` (gap fill). If absent, fetch the latest page and set both cursors. Then subscribe to `events(roomId)`.
2. Events: `MessageChanged` → `upsertMessages` / `deleteMessage` (dedup by `localId`, then `id`); `ReceiptChanged` → update member pointers; `TypingChanged` → in-memory stream only (not cached); `RoomChanged` → rooms table. Advance `newest` cursor when a newer message arrives.
3. `loadOlder`: `cache.messagesBefore(oldest)`; if fewer than `pageSize`, `source.fetchMessages(before: oldest)`, upsert, move `oldest`, store `hasMoreOlder`.
4. `jumpTo`: if the message is in cache and contiguous with the window, return the window; else `fetchAround`, upsert, return a detached window anchored at it.
5. Retention: after sync, `cache.trim(roomId, keep: config.maxCachedMessagesPerRoom)` when set.
6. Every `AppFailure` from the source is rethrown to controllers; cache is never left half-written (use transactions).

### As built

- Windows are values, not repository state. `RoomWindow` is sealed:
  - `LatestWindow{from, hasMoreOlder}` shows every message from `from` (inclusive) up to the newest, so realtime messages appear without touching the window.
  - `DetachedWindow{oldest, newest, hasMoreOlder, hasMoreNewer}` is a slice reached by a jump. `loadNewer` turns it into a `LatestWindow` once it meets the synced range, or when the source reports no newer messages.
- A window never reaches past the contiguous synced range (`RoomSyncState.oldest`..`newest`), so the list never shows a hole.
- `openRoom` returns a `LatestWindow` and is ref-counted, as is `openInbox` / `closeInbox`, which subscribes to room-level events. `loadOlder` / `loadNewer` take the current window and return the next one. `jumpTo(roomId, messageId, current:)` returns `RoomWindow?`, with null when the message can't be found.
- Gap fill is capped at `maxGapPages` (default 5). A bigger gap restarts from the latest page instead of downloading everything. Without `fetchAround`, `jumpTo` pages back up to `maxJumpPages` (default 20).
- One lock per room serializes sync, paging and jumps. Each room's events apply in arrival order through a future chain. Event errors go to `FlutterError.reportError` and never break the stream.
- `newest` only advances from events while the room is synced. `connectionLost()` marks every open room unsynced; `resync()` gap-fills them, refreshes the inbox when it is open, and rethrows the first failure. `ChatKit.setOnline` calls both.
- Typing and presence are held in memory only. Typing ignores the current user, expires after `ChatConfig.typingTimeout`, and is cleared for an author when their message arrives.
- `users(ids)` reads the cache, refreshes missing and stale entries (`userCacheTtl`) through the resolver in batches over a short window (`userBatchWindow`, default 20 ms), shares in-flight lookups, and falls back to the cache when the resolver fails.
- The cache changed for this task (see T03): `watchMessages` / `messages(roomId, from:, to:, limit:)` with inclusive bounds, and `updatePointers` for receipts.
- `ChatKit.repository` is available between `open()` and `close()`.

## Done when

- [x] Tests: gap fill across two rooms does not affect each other's cursor; `loadOlder` uses cache before source; equal timestamps page correctly; realtime echo of own message does not duplicate; `jumpTo` far message returns detached window; `resync` fills a gap after simulated disconnect; source failure leaves cache consistent
- [x] No widget or controller imports `ChatSource` except through the repository and outbox (only `ChatKit`, which owns it, and the repository do)

## Do not

- Keep message lists in repository memory (cache is the store)
- Use offset or growing-limit pagination
