# REST + WebSocket adapter

This guide shows how to back `ChatSource` with your own HTTP API and a
WebSocket for realtime events. The code lives in **your app**; the examples
use `package:http` and `package:web_socket_channel`, but any client works.

```yaml
dependencies:
  flutter_chat_kit: ^0.1.0
  http: ^1.6.0
  lemsa_core_kit: ^1.1.0
  web_socket_channel: ^3.0.3
```

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:http/http.dart' as http;
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
```

## Endpoints

Bodies use the kit's JSON shape (`Message.toJson()`, `ChatRoom.fromJson`);
every field, what is optional and what is forgiven is in
[Backend JSON](../backend_json.md). If your server uses other field names,
pass keys instead of writing mappers:

```dart
static const _keys = ChatJsonKeys(
  authorId: 'sender_id',
  roomKeys: RoomJsonKeys(updatedAt: 'last_activity_at'),
);
// or: static const _keys = ChatJsonKeys.camelCase;
static const _codec = MessageCodec(keys: _keys);

ChatRoom.fromJson(json, keys: _keys);
ChatUser.fromJson(json, keys: _keys.userKeys);
```

Message lists under `/rooms/{id}/messages` usually leave out `room_id`;
pass it when decoding: `_codec.decode(json, roomId: roomId)`. For an API
whose JSON is nested or shaped differently, see
[Plug in an existing API](your_api.md).

| Kit call | HTTP |
| --- | --- |
| `fetchRooms(after, limit, search, filter)` | `GET /rooms?limit=20&after_updated_at=...&after_id=...&q=...&types=direct&labels=work&exclude_labels=archived&unread=true` |
| `fetchMessages(roomId, before)` | `GET /rooms/{id}/messages?limit=30&before_created_at=...&before_id=...` |
| `fetchMessages(roomId, after)` | `GET /rooms/{id}/messages?limit=30&after_created_at=...&after_id=...` |
| `fetchAround(roomId, messageId)` | `GET /rooms/{id}/messages/{messageId}/around?limit=30` |
| `send(pending)` | `PUT /rooms/{id}/messages/{localId}` |
| `edit(message)` | `PATCH /rooms/{id}/messages/{id}` |
| `delete(roomId, messageId)` | `DELETE /rooms/{id}/messages/{id}` (soft delete) |
| `markRead(roomId, upTo)` | `POST /rooms/{id}/read` with `{"created_at", "id"}` |
| `setTyping(roomId, typing)` | WebSocket frame `{"type": "typing", ...}` |
| `react(...)` | `PUT` / `DELETE /rooms/{id}/messages/{id}/reactions/{emoji}` |
| `setPinned` / `setMuted` | `PATCH /rooms/{id}/me` with `{"pinned"}` / `{"muted"}` |

Server rules:

- **Pages are newest first**, with `has_more`: `{"items": [...], "has_more": true}`.
- **Pages can carry their people**: `"users": [{"id", "name", "avatar_url"}]`
  for the message authors and room members of the page. The kit saves them,
  shows them, and replaces them when a name or avatar changes, so you need
  no `ChatUserResolver` for them.
- **Cursors are exclusive keyset bounds** on `(created_at, id)` for messages
  and `(updated_at, id)` for rooms:
  `WHERE (created_at, id) < (:before_created_at, :before_id)
  ORDER BY created_at DESC, id DESC LIMIT :limit + 1`.
  The `after_*` form reads ascending and the server (or client) reverses it.
- **`PUT .../messages/{localId}` is idempotent.** Store `local_id` with a
  unique index. A repeated PUT returns the stored message with `200` instead
  of creating a second one.
- The WebSocket also delivers the **sender's own** messages. The kit
  deduplicates by `localId`.
- **Room filters are optional.** `types`, `labels` (any of),
  `exclude_labels` and `unread` come from `RoomFilter.toQuery()`. A server
  that ignores them still works: the kit filters on the device. Labels are
  per user (`"labels": ["work"]` in the room JSON).
- No WebSocket? See [mixing backends](mixing.md): keep this REST source for
  data and use `PollingRealtime`, or Firebase / Supabase, for events.

## Errors

```dart
AppFailure _failure(Object error, [http.Response? res]) {
  if (error is AppFailure) return error;
  if (res != null) {
    return switch (res.statusCode) {
      401 => AuthFailure(AuthReason.expired, cause: res.body),
      403 => PermissionFailure('chat', cause: res.body),
      404 => NotFoundFailure('chat', cause: res.body),
      408 || 504 => TimeoutFailure(cause: res.body),
      409 => ConflictFailure(cause: res.body),
      422 => ValidationFailure(const {}, cause: res.body),
      502 || 503 => NetworkFailure(cause: res.body),
      _ => ServerFailure(status: res.statusCode, cause: res.body),
    };
  }
  return switch (error) {
    SocketException() || http.ClientException() => NetworkFailure(cause: error),
    TimeoutException() => TimeoutFailure(cause: error),
    _ => UnknownFailure(cause: error),
  };
}
```

`NetworkFailure` and `TimeoutFailure` make the outbox retry with backoff;
anything else marks the message as failed and shows the retry action.

## The source

```dart
class RestChatSource implements ChatSource {
  RestChatSource({
    required this.baseUrl,
    required this.socketUrl,
    required this.token,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final Uri baseUrl;
  final Uri socketUrl;
  final Future<String> Function() token;
  final http.Client _http;
  static const _codec = MessageCodec();

  Future<Object?> _call(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
  }) async {
    final uri = baseUrl.replace(
      path: '${baseUrl.path}$path',
      queryParameters: {
        for (final MapEntry(:key, :value) in query.entries)
          if (value != null) key: value,
      },
    );
    http.Response? res;
    try {
      final req = http.Request(method, uri)
        ..headers['authorization'] = 'Bearer ${await token()}'
        ..headers['content-type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 20)),
      );
      if (res.statusCode >= 300) throw _failure(res, res);
      return res.body.isEmpty ? null : jsonDecode(res.body);
    } on AppFailure {
      rethrow;
    } on Object catch (e) {
      throw _failure(e, res);
    }
  }

  ChatPage<T> _page<T>(Object? json, T Function(Map<String, Object?>) item) {
    final map = json! as Map<String, Object?>;
    return ChatPage(
      items: [
        for (final i in map['items']! as List) item(i as Map<String, Object?>),
      ],
      hasMore: map['has_more'] == true,
      users: [
        for (final u in map['users'] as List? ?? const [])
          ChatUser.fromJson(u as Map<String, Object?>),
      ],
    );
  }

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async => _page(
    await _call('GET', '/rooms', query: {
      'limit': '$limit',
      'after_updated_at': after?.updatedAt.toIso8601String(),
      'after_id': after?.id,
      'q': search,
      ...filter.toQuery(),
    }),
    ChatRoom.fromJson,
  );

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async => _page(
    await _call('GET', '/rooms/$roomId/messages', query: {
      'limit': '$limit',
      'before_created_at': before?.createdAt.toIso8601String(),
      'before_id': before?.id,
      'after_created_at': after?.createdAt.toIso8601String(),
      'after_id': after?.id,
    }),
    (json) => _codec.decode(json, roomId: roomId),
  );

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) async => _page(
    await _call(
      'GET',
      '/rooms/$roomId/messages/$messageId/around',
      query: {'limit': '$limit'},
    ),
    (json) => _codec.decode(json, roomId: roomId),
  );

  @override
  Future<Message> send(Message pending) async => _codec.decode(
    await _call(
      'PUT',
      '/rooms/${pending.roomId}/messages/${pending.localId}',
      body: pending.toJson(),
    ) as Map<String, Object?>,
  );

  @override
  Future<Message> edit(Message message) async => _codec.decode(
    await _call(
      'PATCH',
      '/rooms/${message.roomId}/messages/${message.id}',
      body: message.toJson(),
    ) as Map<String, Object?>,
  );

  @override
  Future<void> delete(String roomId, String messageId) =>
      _call('DELETE', '/rooms/$roomId/messages/$messageId');

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) =>
      _call('POST', '/rooms/$roomId/read', body: upTo.toJson());

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) => _call(
    add ? 'PUT' : 'DELETE',
    '/rooms/$roomId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}',
  );

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) =>
      _call('PATCH', '/rooms/$roomId/me', body: {'pinned': pinned});

  @override
  Future<void> setMuted(String roomId, {required bool muted}) =>
      _call('PATCH', '/rooms/$roomId/me', body: {'muted': muted});

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async =>
      _socket.send({'type': 'typing', 'room_id': roomId, 'typing': typing});

  late final _socket = ChatSocket(socketUrl, token);

  @override
  Stream<ChatEvent> events({String? roomId}) => _socket.events(roomId);
}
```

## WebSocket frames to `ChatEvent`

| Frame `type` | Payload | Event |
| --- | --- | --- |
| `message.created` | `room_id`, `message` | `MessageChanged(roomId, Created(message))` |
| `message.updated` | `room_id`, `message` (edits, reactions, deletes) | `MessageChanged(roomId, Updated(message))` |
| `message.deleted` | `room_id`, `id` (hard delete) | `MessageChanged(roomId, Deleted(id))` |
| `room.updated` | `room` | `RoomChanged(Updated(room))` |
| `room.removed` | `id` (left or kicked) | `RoomChanged(Deleted(id))` |
| `typing` | `room_id`, `user_id`, `typing` | `TypingChanged(...)` |
| `receipt` | `room_id`, `user_id`, `read_at`, `delivered_at` | `ReceiptChanged(...)` |
| `presence` | `user_id`, `online`, `last_seen_at` | `PresenceChanged(Presence(...))` |
| `user.updated` | `user` (`id`, `name`, `avatar_url`) | `UsersChanged([user])` |

Room streams (`events(roomId: id)`) get the message, typing and receipt
frames for that room. The inbox stream (`events()`) gets the room and
presence frames. `user.updated` (a rename or a new avatar) works on both. Tell the server what to send by subscribing:
`{"type": "subscribe", "room_id": "..."}`.

```dart
class ChatSocket {
  ChatSocket(this.url, this.token);

  final Uri url;
  final Future<String> Function() token;
  static const _codec = MessageCodec();

  WebSocketChannel? _channel;
  final _frames = StreamController<Map<String, Object?>>.broadcast();
  final _rooms = <String>{};
  var _attempt = 0;

  Future<void> _connect() async {
    if (_channel != null) return;
    final channel = WebSocketChannel.connect(
      url.replace(queryParameters: {'token': await token()}),
    );
    _channel = channel;
    try {
      await channel.ready;
      _attempt = 0;
      for (final r in _rooms) send({'type': 'subscribe', 'room_id': r});
    } on Object catch (e) {
      _frames.addError(NetworkFailure(cause: e));
    }
    channel.stream.listen(
      (raw) => _frames.add(jsonDecode(raw as String) as Map<String, Object?>),
      onError: (Object e) => _frames.addError(NetworkFailure(cause: e)),
      onDone: _reconnect,
    );
  }

  void _reconnect() {
    _channel = null;
    if (!_frames.hasListener) return;
    final delay = Duration(seconds: min(30, 1 << _attempt++));
    Timer(delay, _connect);
  }

  void send(Map<String, Object?> frame) =>
      _channel?.sink.add(jsonEncode(frame));

  Stream<ChatEvent> events(String? roomId) async* {
    if (roomId != null) {
      _rooms.add(roomId);
      send({'type': 'subscribe', 'room_id': roomId});
    }
    unawaited(_connect());
    try {
      await for (final f in _frames.stream) {
        final frameRoom = f['room_id'];
        if (roomId != null && frameRoom != null && frameRoom != roomId) {
          continue;
        }
        if (_toEvent(f, inbox: roomId == null) case final e?) yield e;
      }
    } finally {
      if (roomId != null) {
        _rooms.remove(roomId);
        send({'type': 'unsubscribe', 'room_id': roomId});
      }
    }
  }

  ChatEvent? _toEvent(Map<String, Object?> f, {required bool inbox}) {
    final roomId = f['room_id'] as String?;
    Message message() => _codec.decode(f['message']! as Map<String, Object?>);
    return switch (f['type']) {
      'message.created' when !inbox =>
        MessageChanged(roomId: roomId!, change: Created(message())),
      'message.updated' when !inbox =>
        MessageChanged(roomId: roomId!, change: Updated(message())),
      'message.deleted' when !inbox =>
        MessageChanged(roomId: roomId!, change: Deleted(f['id']! as String)),
      'typing' when !inbox => TypingChanged(
        roomId: roomId!,
        userId: f['user_id']! as String,
        typing: f['typing'] == true,
      ),
      'receipt' when !inbox => ReceiptChanged(
        roomId: roomId!,
        userId: f['user_id']! as String,
        readAt: DateTime.tryParse('${f['read_at']}'),
        deliveredAt: DateTime.tryParse('${f['delivered_at']}'),
      ),
      'room.updated' when inbox => RoomChanged(
        Updated(ChatRoom.fromJson(f['room']! as Map<String, Object?>)),
      ),
      'room.removed' when inbox => RoomChanged(Deleted(f['id']! as String)),
      'presence' when inbox => PresenceChanged(
        Presence(
          userId: f['user_id']! as String,
          isOnline: f['online'] == true,
          lastSeenAt: DateTime.tryParse('${f['last_seen_at']}'),
        ),
      ),
      'user.updated' => UsersChanged([
        ChatUser.fromJson(f['user']! as Map<String, Object?>),
      ]),
      _ => null,
    };
  }
}
```

## Connectivity

The kit resubscribes and fills gaps when you call
`kit.setOnline(online: true)` after being offline. Drive it from your
connectivity source, for example with `connectivity_plus`:

```dart
Connectivity().onConnectivityChanged.listen((results) {
  kit.setOnline(online: !results.contains(ConnectivityResult.none));
});
```

## Uploads

Any storage works. A typical pattern is a pre-signed URL from your API:

```dart
class PresignedUploader implements ChatUploader {
  PresignedUploader(this._source);

  final RestChatSource _source;

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    final slot = await _source._call('POST', '/uploads', body: {
      'room_id': roomId,
      'local_id': localId,
      'mime_type': attachment.mimeType,
      'name': attachment.name,
    }) as Map<String, Object?>;
    yield const UploadRunning(0);
    final bytes = await File(attachment.localPath!).readAsBytes();
    final res = await http.put(
      Uri.parse(slot['upload_url']! as String),
      headers: {'content-type': attachment.mimeType},
      body: bytes,
    );
    if (res.statusCode >= 300) throw ServerFailure(status: res.statusCode);
    yield UploadDone(remoteUrl: slot['public_url']! as String);
  }
}
```

For real progress, stream the file through `http.StreamedRequest` and count
the bytes you add to its sink.
