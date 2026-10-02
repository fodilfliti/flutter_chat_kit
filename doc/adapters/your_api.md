# Plug in an existing API

Your backend already exists and has its own JSON: numeric ids, camelCase,
a nested `sender`, a `files` array, its own type names. You don't have to
change it. This guide goes from a working chat on fake data to your API in
six steps.

1. [See the chat on fake data](#1-see-the-chat-on-fake-data)
2. [Map your endpoints](#2-map-your-endpoints)
3. [Read your JSON](#3-read-your-json)
4. [Check real responses](#4-check-real-responses)
5. [Live updates](#5-live-updates)
6. [Uploads](#6-uploads)

The JSON the kit reads, and what it forgives, is in
[Backend JSON](../backend_json.md).

## 1. See the chat on fake data

Start with `InMemoryChatSource`. It's a complete source kept in memory:
sample rooms and people, paging, idempotent send, receipts, typing and
auto replies. Build your screens on it first.

```dart
final kit = ChatKit(
  currentUserId: 'me',
  source: InMemoryChatSource.sample(currentUserId: 'me'),
);
await kit.open();
```

To try your own data, seed it:

```dart
final source = InMemoryChatSource(
  currentUserId: 'me',
  rooms: [ChatRoom.fromJson(roomJson)],
  messages: {'r1': [for (final m in messagesJson) Message.fromJson(m, roomId: 'r1')]},
  users: [const ChatUser(id: 'u2', name: 'Sara')],
  autoReply: true,
);
source.receive(someMessage); // as if someone wrote
```

When the screens look right, write your own `ChatSource` and swap it in.
Nothing else in the app changes.

## 2. Map your endpoints

`ChatSource` is the only thing you implement. Mix in `ChatSourceDefaults`
and the optional parts (reactions, pin, mute, typing, jump to a message)
become no-ops you can fill in later.

| `ChatSource` method | Typical endpoint | If your API doesn't have it |
| --- | --- | --- |
| `fetchRooms(after, limit, search, filter)` | `GET /conversations` | Return every room in one page with `hasMore: false` (fine up to a few hundred). Avoid page numbers: a new message moves rooms between pages. |
| `fetchMessages(roomId, before)` | `GET /conversations/{id}/messages?before=...` | Needed for scrolling back. A `before` timestamp is enough; page numbers are not. |
| `fetchMessages(roomId, after)` | same, with `?after=...` | Used each time a room opens, to fetch what arrived since the newest cached message. Without it, return the newest page filtered to items newer than `after`, with `hasMore: false`; if more than a page arrived meanwhile, the ones in between are skipped. Add `after` when you can. |
| `send(pending)` | `POST /conversations/{id}/messages` | Required. Make it idempotent (below). |
| `edit(message)` | `PATCH /messages/{id}` | Throw a `ValidationFailure`; the edit fails visibly. |
| `delete(roomId, messageId)` | `DELETE /messages/{id}` | Same as edit. |
| `markRead(roomId, upTo)` | `POST /conversations/{id}/read` | Do nothing: no read ticks for the other side. |
| `events(roomId)` | WebSocket, SSE, Firebase, Supabase | `PollingRealtime` (step 5). |
| `react`, `setPinned`, `setMuted`, `setTyping`, `fetchAround` | | Leave them to `ChatSourceDefaults`. Pin and mute then stay on the device. |

**Make send idempotent.** The kit retries a send after a timeout or a
restart, keyed by `pending.localId` (a UUID). Store it with a unique index
and return the stored message when it comes again. If your API can't,
send `localId` as an `Idempotency-Key` header and dedupe in a proxy, or
accept a rare duplicate.

**Return the saved message** with your id and time, and with the
`localId` you received, so the pending bubble turns into it.

The skeleton:

```dart
class MyApiSource with ChatSourceDefaults {
  MyApiSource(this.api);

  final MyApiClient api; // your existing client

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    final res = await api.getConversations(
      updatedBefore: after?.updatedAt,
      limit: limit,
      query: search,
    );
    return ChatPage(
      items: [for (final c in res.items) toRoom(c)],
      hasMore: res.hasMore,
      users: [for (final c in res.items) ...peopleOf(c)],
    );
  }

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    final res = await api.getMessages(
      roomId,
      before: before?.createdAt,
      after: after?.createdAt,
      limit: limit,
    );
    return ChatPage(
      items: [for (final m in res.items) toMessage(m, roomId)], // newest first
      hasMore: res.hasMore,
      users: [for (final m in res.items) senderOf(m)],
    );
  }

  @override
  Future<Message> send(Message pending) async {
    final saved = await api.postMessage(pending.roomId, toApi(pending));
    return toMessage(saved, pending.roomId);
  }

  @override
  Future<Message> edit(Message message) async =>
      toMessage(await api.patchMessage(message.id, toApi(message)), message.roomId);

  @override
  Future<void> delete(String roomId, String messageId) =>
      api.deleteMessage(messageId);

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) =>
      api.markRead(roomId, upTo.createdAt);

  @override
  Stream<ChatEvent> events({String? roomId}) => const Stream.empty(); // step 5
}
```

Turn your client's errors into `AppFailure`s (from `lemsa_core_kit`):
`NetworkFailure` and `TimeoutFailure` make the outbox retry with backoff;
anything else marks the message failed with a retry button. The
[REST guide](rest_websocket.md#errors) has a ready mapping from status
codes.

## 3. Read your JSON

Pick the lightest option that fits.

### Flat JSON with other names: `ChatJsonKeys`

```json
{ "messageId": 991, "senderId": 7, "sentAt": 1759233600000, "kind": "photo",
  "photos": ["https://cdn.example.com/x.jpg"], "caption": "Look" }
```

```dart
const keys = ChatJsonKeys(
  id: 'messageId',
  authorId: 'senderId',
  createdAt: 'sentAt',
  type: 'kind',
  attachments: 'photos',
  typeAliases: {'photo': 'image', 'voice': 'audio', 'doc': 'file'},
);

Message toMessage(Map<String, Object?> json, String roomId) =>
    Message.fromJson(json, keys: keys, roomId: roomId);
```

Numbers become string ids, epoch seconds or milliseconds become dates,
bare URLs become attachments, and the mime type is guessed from the
extension (or from the message type when there is none).

### camelCase JSON: the preset

```dart
final message = Message.fromJson(json, keys: ChatJsonKeys.camelCase, roomId: roomId);
final room = ChatRoom.fromJson(json, keys: ChatJsonKeys.camelCase);
final user = ChatUser.fromJson(json, keys: UserJsonKeys.camelCase);
```

The full name list is in [Backend JSON](../backend_json.md#other-field-names-chatjsonkeys).

### Nested or split JSON: a small mapper

When the sender is an object or files live in their own array, reshape the
map into the kit's shape first, then let `Message.fromJson` do the rest
(dates, ids, mime guessing, unknown types).

Your API:

```json
{
  "messageId": 991,
  "clientId": "5f0c1c6e-...",
  "sender": { "id": 7, "name": "Sara", "photo": "https://cdn.example.com/sara.jpg" },
  "kind": "photo",
  "body": "Look at this",
  "files": [ { "url": "https://cdn.example.com/x.jpg", "w": 1280, "h": 960 } ],
  "sentAt": "2026-09-30T12:00:00Z",
  "seenBy": [7]
}
```

The mapper:

```dart
Message toMessage(Map<String, Object?> m, String roomId) {
  final sender = m['sender']! as Map<String, Object?>;
  final files = (m['files'] as List? ?? const []).cast<Map<String, Object?>>();
  final type = switch (m['kind']) {
    'photo' => 'image',
    'video' => 'video',
    'voice' => 'audio',
    'doc' => 'file',
    final String other => other, // unknown kinds become CustomMessage
    _ => 'text',
  };
  return Message.fromJson({
    'id': m['messageId'],
    'local_id': m['clientId'],
    'author_id': sender['id'],
    'created_at': m['sentAt'],
    'type': type,
    'text': m['body'],
    'caption': m['body'],
    'attachments': [
      for (final f in files)
        {
          'url': f['url'],
          'width': f['w'],
          'height': f['h'],
          'name': f['fileName'],
          'duration_ms': f['durationMs'],
        },
    ],
    'duration_ms': files.firstOrNull?['durationMs'],
  }, roomId: roomId);
}

ChatUser senderOf(Map<String, Object?> m) {
  final s = m['sender']! as Map<String, Object?>;
  return ChatUser(id: '${s['id']}', name: '${s['name'] ?? ''}', avatarUrl: s['photo'] as String?);
}
```

Return the senders in `ChatPage.users`, as in the skeleton, and names and
photos show without a `ChatUserResolver`.

A room works the same way:

```dart
ChatRoom toRoom(Map<String, Object?> c) {
  final id = '${c['conversationId']}';
  return ChatRoom.fromJson({
    'id': id,
    'type': c['isGroup'] == true ? 'group' : 'direct',
    'title': c['name'],
    'avatar_url': c['image'],
    'members': [
      for (final p in (c['participants'] as List? ?? const []).cast<Map<String, Object?>>())
        {'user_id': p['userId'], 'last_read_at': p['lastSeenMessageAt']},
    ],
    'unread_count': c['unread'],
    'updated_at': c['lastActivityAt'], // optional: falls back to the last message
    'last_message': switch (c['lastMessage']) {
      final Map<String, Object?> last => toMessage(last, id).toJson(),
      _ => null,
    },
  });
}
```

The last message goes through the same message mapper, so the inbox
preview matches the room.

### Sending in your format

Map the outgoing message the other way. Switch on the type so every kind
is handled:

```dart
Map<String, Object?> toApi(Message m) => {
  'clientId': m.localId, // the idempotency key
  ...switch (m) {
    TextMessage(:final text) => {'kind': 'text', 'body': text},
    ImageMessage(:final images, :final caption) => {
      'kind': 'photo',
      'body': caption,
      'files': [for (final i in images) {'url': i.remoteUrl, 'w': i.width, 'h': i.height}],
    },
    VideoMessage(:final video, :final caption) => {
      'kind': 'video',
      'body': caption,
      'files': [{'url': video.remoteUrl, 'w': video.width, 'h': video.height}],
    },
    AudioMessage(:final audio, :final duration) => {
      'kind': 'voice',
      'files': [{'url': audio.remoteUrl, 'durationMs': duration.inMilliseconds}],
    },
    FileMessage(:final file) => {
      'kind': 'doc',
      'files': [{'url': file.remoteUrl, 'fileName': file.name}],
    },
    CustomMessage(:final customType, :final data) => {'kind': customType, ...data},
    SystemMessage() => throw const ValidationFailure({'type': 'system'}),
  },
};
```

By the time `send` runs, the uploader has already put the files online, so
`remoteUrl` is set.

If your API uses the kit's own shape with other names, skip the mapper:
`MessageCodec(keys: keys).encode(message)`.

## 4. Check real responses

Save one real response of each endpoint under `test/fixtures/` and check
it once. `ChatJsonCheck` lists every field the kit can't read, or reads with
a guess, and says how to fix it:

```dart
test('conversation messages fit the kit', () {
  final res = jsonDecode(File('test/fixtures/messages.json').readAsStringSync())
      as Map<String, Object?>;
  for (final m in (res['items']! as List).cast<Map<String, Object?>>()) {
    final message = toMessage(m, 'r1'); // throws with a clear message if broken
    final issues = ChatJsonCheck.message(message.toJson());
    expect(issues, isEmpty, reason: issues.join('\n'));
  }
});
```

Without a mapper, check the raw JSON with your keys:
`ChatJsonCheck.message(json, keys: keys, roomId: 'r1')`. Use
`ChatJsonCheck.room` and `ChatJsonCheck.user` for the other endpoints.

Checking after a mapper still catches missing sizes, missing durations
and unknown types. Checking the raw JSON also catches dates without a time
zone and epoch seconds.

## 5. Live updates

`events(roomId: id)` feeds an open room (new and changed messages, typing,
receipts), and `events()` feeds the inbox (room changes, presence). Pick
what your backend has:

- **A WebSocket, SSE, Pusher, Ably or MQTT**: decode each frame into a
  `ChatEvent`. The [REST + WebSocket guide](rest_websocket.md#websocket-frames-to-chatevent)
  has the frame table and a reconnecting socket.
- **Firebase or Supabase next to your API** (the server mirrors writes):
  keep your API for data and use their realtime, with `ComposedChatSource`.
  See [mixing backends](mixing.md#mixing-backends).
- **Nothing**: `PollingRealtime` polls the open room and the inbox through
  your own `fetchMessages` and `fetchRooms`.

```dart
final api = MyApiSource(client);
final kit = ChatKit(
  currentUserId: me,
  source: ComposedChatSource(data: api, realtime: PollingRealtime(api)),
);
```

`MyApiSource` keeps its own `events`; `ComposedChatSource` only takes the
data half from it.

Push notifications are for when the app is closed. While it's open, if a
push arrives for a room the user isn't in, call `inbox.refresh()` so the
list updates without waiting for the next poll.

Your own sent message usually comes back through the live channel too; the
kit matches it by `localId`, so echo it.

## 6. Uploads

Media and voice need a `ChatUploader`; without one the kit hides the attach
and mic buttons. It receives the local file and yields its URL:

```dart
class MyUploader implements ChatUploader {
  MyUploader(this.api);

  final MyApiClient api;

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    yield const UploadRunning(0);
    final url = await api.uploadFile(
      attachment.localPath!,
      mimeType: attachment.mimeType,
      onProgress: (fraction) {}, // yield UploadRunning(fraction) from a stream
    );
    yield UploadDone(remoteUrl: url);
  }
}

final kit = ChatKit(currentUserId: me, source: source, uploader: MyUploader(client));
```

The kit uploads before calling `send`, retries failed uploads with the
message, and puts the URL into the attachment's `remoteUrl`. Pre-signed
URLs, Firebase Storage and Supabase Storage examples are in the
[REST](rest_websocket.md#uploads), [Firestore](firestore.md) and
[Supabase](supabase.md) guides.
