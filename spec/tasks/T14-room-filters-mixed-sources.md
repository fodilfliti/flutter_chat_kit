# T14 — Several chat lists, mixed backends

## Goal

1. One backend, several lists: a "Chats" tab with direct rooms, a "Groups" tab, an "Archived" label, an "Unread" filter. Each list pages, searches and counts unread on its own.
2. Mixed backends: data from one system (usually a REST API) and realtime from another (Firebase, Supabase, WebSocket), or REST alone with polling.

## Read first

- [../package.md](../package.md), [T04](T04-repository-sync.md), [T06](T06-controllers.md)

## Depends on

T13.

## Deliverables

```text
lib/src/models/chat_room.dart              ChatRoom.labels (Set<String>, JSON "labels")
lib/src/models/room_filter.dart            RoomFilter (types, labels, unreadOnly, where), matches, toQuery
lib/src/cache/drift/tables.dart            rooms.labels_json; schema v3 (add column)
lib/src/source/chat_source.dart            ChatDataSource + ChatRealtime; ChatSource = both; fetchRooms(filter:)
lib/src/source/composed_chat_source.dart   ComposedChatSource(data:, realtime:)
lib/src/source/polling_realtime.dart       PollingRealtime(data, roomInterval, inboxInterval)
lib/src/sync/chat_repository.dart          stateless fetchRooms(after, search, filter); watchRooms(filter); per-inbox resync callbacks
lib/src/controllers/inbox_controller.dart  filter, setFilter, own cursor
lib/src/controllers/chat_kit.dart          inbox({RoomFilter filter})
doc/adapters/mixing.md                     compose REST data + realtime; REST-only polling
```

## Public API

```dart
final chats = kit.inbox(filter: RoomFilter.direct);
final groups = kit.inbox(filter: RoomFilter.groups);
final archived = kit.inbox(filter: const RoomFilter(labels: {'archived'}));
inbox.setFilter(const RoomFilter(unreadOnly: true));

final source = ComposedChatSource(
  data: MyRestApi(),                        // ChatDataSource
  realtime: PollingRealtime(api),           // or a Firebase / Supabase / WebSocket ChatRealtime
);
```

## Done when

- [x] Two inbox controllers with different filters page and search independently; the backend may ignore the filter and the lists stay correct
- [x] `setFilter` switches the list without a new controller; `resync` refreshes the first page of every open inbox query
- [x] Labels round-trip through JSON and the cache; v2 databases migrate
- [x] `ComposedChatSource` routes calls; `PollingRealtime` emits new and changed messages and rooms, and fills bursts larger than a page
- [x] Example shows filter chips; guides updated and compile-checked; analyze and tests green

## As built

- `RoomFilter` also has `excludeLabels` (for example `{'archived'}` on the main list) and `copyWith`; presets `all`, `direct`, `groups`.
- `ChatRepository.fetchRooms` returns `RoomsPageInfo` (`hasMore`, `next`). An empty page ends paging, so an adapter that drops rooms after its query cannot loop. `refreshRooms` / `loadMoreRooms` are gone.
- `openInbox({onResync})` / `closeInbox({onResync})`: each `InboxController` registers a first-page refetch; `resync` runs all of them and rethrows the first failure. A stale `loadMore` (search or filter changed meanwhile) is dropped.
- `InboxView` keeps paging while a filtered list is empty or short and shows the loading state instead of "empty" while more pages exist.
- `PollingRealtime` also takes `pageSize`, `roomsPageSize` and `maxCatchUpPages`; the room poll starts at once, the inbox poll after the first interval.
- `build.yaml` limits code generation to `lib/`.
- Guides: Firestore filters `type` with `whereIn` (labels stay local, labels stored per user in `labels.{uid}`); Supabase filters on an inner-joined `me:room_members` (per-user `labels text[]`); REST spreads `filter.toQuery()`. `doc/adapters/mixing.md` covers tabs, composing, polling and two separate kits (own database name and media folder).

## Do not

- Keep paging state shared between inbox controllers
- Require backends to support every filter (local filtering is the fallback)
