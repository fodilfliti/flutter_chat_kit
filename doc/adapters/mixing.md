# Several chat lists and mixed backends

This guide covers three setups:

1. [Several chat lists from one backend](#several-chat-lists-from-one-backend):
   a "Chats" tab and a "Groups" tab, labels, an unread list.
2. [Mixing backends](#mixing-backends): data from a REST API with realtime
   from Firebase, Supabase or a WebSocket, or REST alone with polling.
3. [Two separate chat systems](#two-separate-chat-systems) in one app.

## Several chat lists from one backend

One `ChatKit` holds every room of the user. Each list on screen is its own
`InboxController` with a `RoomFilter`:

```dart
final chats = kit.inbox(filter: RoomFilter.direct);   // one-to-one
final groups = kit.inbox(filter: RoomFilter.groups);  // groups and channels
final work = kit.inbox(filter: const RoomFilter(labels: {'work'}));
final unread = kit.inbox(filter: const RoomFilter(unreadOnly: true));
final main = kit.inbox(
  filter: const RoomFilter(excludeLabels: {'archived'}),
);
```

Each controller has its own paging, search and `totalUnread`, so tab
badges come for free. They share the local database and one inbox event
subscription, so a new message updates every list that shows the room.
Dispose each controller with its page.

```dart
class ChatTabs extends StatefulWidget {
  const ChatTabs({required this.kit, super.key});

  final ChatKit kit;

  @override
  State<ChatTabs> createState() => _ChatTabsState();
}

class _ChatTabsState extends State<ChatTabs> {
  late final _chats = widget.kit.inbox(filter: RoomFilter.direct);
  late final _groups = widget.kit.inbox(filter: RoomFilter.groups);

  @override
  void dispose() {
    _chats.dispose();
    _groups.dispose();
    super.dispose();
  }

  Widget _tab(String label, InboxController inbox) => ListenableBuilder(
    listenable: inbox,
    builder: (context, _) => Tab(
      text: inbox.totalUnread == 0 ? label : '$label (${inbox.totalUnread})',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [_tab('Chats', _chats), _tab('Groups', _groups)],
          ),
        ),
        body: TabBarView(
          children: [
            InboxView(controller: _chats, onRoomTap: _open),
            InboxView(controller: _groups, onRoomTap: _open),
          ],
        ),
      ),
    );
  }

  void _open(ChatRoom room) {
    // Push your room page.
  }
}
```

For chips over a single list, keep one controller and call
`inbox.setFilter(RoomFilter.groups)`; it switches the list and fetches the
first page again.

### Filter fields

| Field | Matches |
| --- | --- |
| `types` | `RoomType.direct`, `group`, `channel` (null: any) |
| `labels` | rooms with at least one of these labels |
| `excludeLabels` | rooms with none of these labels |
| `unreadOnly` | `unreadCount > 0` |
| `where` | any Dart condition; checked on the device only |

`ChatRoom.labels` are app-defined categories per user ("work",
"archived", ...). They come from your backend like `pinned` and `muted`
(`"labels": ["work"]` in the room JSON) and are stored in the local cache.

### What the backend sees

The filter is passed to `ChatDataSource.fetchRooms(filter: ...)`. Apply what
the query can do and ignore the rest:

- REST: `...filter.toQuery()` adds `types`, `labels`, `exclude_labels` and
  `unread` parameters ([REST guide](rest_websocket.md)).
- Supabase: `inFilter('type', ...)`, `overlaps` on the member's labels
  ([Supabase guide](supabase.md)).
- Firestore: `where('type', whereIn: ...)`; labels stay on the device
  ([Firestore guide](firestore.md)).

The kit always filters its cache again, so a backend that ignores the
filter still shows the right rooms; the list keeps loading pages until it
has enough. Do not drop rooms from a page after the query ran: the next
page starts after the last room returned.

## Mixing backends

The backend contract has two halves:

- `ChatDataSource`: reads and writes (rooms, messages, send, edit, delete,
  read pointers, reactions, pin, mute).
- `ChatRealtime`: `events()` and `setTyping()`.

`ChatSource` is both. `ComposedChatSource` builds one from two parts, so
each half can come from a different service:

```dart
final api = MyRestApi(baseUrl: Uri.parse('https://api.example.com'));

final kit = ChatKit(
  currentUserId: uid,
  source: ComposedChatSource(
    data: api,
    realtime: SupabaseChatSource(Supabase.instance.client),
    // realtime: FirestoreChatSource(FirebaseFirestore.instance, uid),
    // realtime: MySocketRealtime(socketUrl),
    // realtime: PollingRealtime(api), // no realtime service at all
  ),
);
```

A full adapter from the other guides (`SupabaseChatSource`,
`FirestoreChatSource`) is also a `ChatRealtime`, so it can serve the
realtime half as is. Only its `events` and `setTyping` are used.

Rules when mixing:

- **Same ids on both sides.** Room ids, message ids and `localId`s from the
  realtime side must match the ones the REST API returns. A common setup is
  a server that writes to its database and mirrors changes to Firestore or
  Supabase for fan-out.
- **Same message shape.** Decode both with the same `MessageCodec` (and
  `ChatJsonKeys` if your field names differ).
- **Your own messages come back.** The realtime side may deliver the
  message you just sent through REST; the kit deduplicates by `localId`.

### The REST data half

Implement only the data methods. `ChatDataSourceDefaults` makes reactions,
pin, mute and `fetchAround` optional:

```dart
class MyRestApi with ChatDataSourceDefaults {
  MyRestApi({required this.baseUrl});

  final Uri baseUrl;

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    // GET /rooms?limit=...&after_updated_at=...&q=...&types=...
    throw UnimplementedError();
  }

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async => throw UnimplementedError();

  @override
  Future<Message> send(Message pending) async => throw UnimplementedError();

  @override
  Future<Message> edit(Message message) async => throw UnimplementedError();

  @override
  Future<void> delete(String roomId, String messageId) async {}

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) async {}
}
```

The bodies are the same as in the [REST guide](rest_websocket.md); only the
WebSocket part moves out.

### A custom realtime half

Any stream of `ChatEvent`s works: a WebSocket, Server-Sent Events, Pusher,
Ably, MQTT. See [REST + WebSocket](rest_websocket.md) for decoding frames.

```dart
class MySocketRealtime implements ChatRealtime {
  MySocketRealtime(this.url);

  final Uri url;

  @override
  Stream<ChatEvent> events({String? roomId}) {
    // Connect, subscribe to the room (or the inbox when roomId is null),
    // decode frames into MessageChanged / RoomChanged / TypingChanged /
    // ReceiptChanged / PresenceChanged, and close when cancelled.
    throw UnimplementedError();
  }

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {
    // Send a typing frame, or do nothing.
  }
}
```

### REST only: `PollingRealtime`

Without any realtime service, `PollingRealtime` polls the REST API while a
room or the inbox is open:

```dart
final api = MyRestApi(baseUrl: baseUrl);
final source = ComposedChatSource(
  data: api,
  realtime: PollingRealtime(
    api,
    roomInterval: const Duration(seconds: 3),   // open room
    inboxInterval: const Duration(seconds: 15), // room list
  ),
);
```

- An open room fetches its latest page and emits new and changed messages
  (edits, reactions, soft deletes). After a burst larger than one page it
  reads forward from the newest known message, so nothing is skipped.
- The inbox fetches the first page of rooms and emits the rooms that
  changed. Read receipts arrive through the room members.
- Only screens that are open poll; a closed room costs nothing.
- Failed polls are skipped; the next one retries.

Limits:

- **Use soft deletes** (`deleted_at`). A message missing from the latest
  page cannot be told apart from one that scrolled out of it.
- No typing indicator and no presence.
- Changes show up after the interval, not instantly. Pick the intervals
  from your server's load budget.

## Two separate chat systems

When two chat products have nothing in common (for example user chat on
Supabase and a support desk on a REST API), create two kits. Give the
second one its own database and media folder, since both default to the
user id:

```dart
final userChat = ChatKit(currentUserId: uid, source: supabaseSource);

final support = ChatKit(
  currentUserId: uid,
  source: ComposedChatSource(data: supportApi, realtime: PollingRealtime(supportApi)),
  cache: DriftChatCache(
    executorFactory: (userId) => openChatDatabase('support_$userId'),
  ),
  mediaStore: (kit) => ChatMediaStore(
    userId: 'support_${kit.currentUserId}',
    cache: kit.cache,
    clock: kit.clock,
  ),
);
```

Open, provide (`ChatKitScope`) and close each kit on its own. Rooms of one
kit never appear in the other.
