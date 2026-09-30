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

## Done when

- [ ] Tests: gap fill across two rooms does not affect each other's cursor; `loadOlder` uses cache before source; equal timestamps page correctly; realtime echo of own message does not duplicate; `jumpTo` far message returns detached window; `resync` fills a gap after simulated disconnect; source failure leaves cache consistent
- [ ] No widget or controller imports `ChatSource` except through the repository and outbox

## Do not

- Keep message lists in repository memory (cache is the store)
- Use offset or growing-limit pagination
