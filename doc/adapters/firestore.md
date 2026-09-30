# Firestore adapter

This guide shows one way to implement `ChatSource` and `ChatUploader` on
Cloud Firestore and Firebase Storage. The code lives in **your app**: the
kit never depends on Firebase.

```yaml
dependencies:
  cloud_firestore: ^6.10.0
  firebase_storage: ^13.6.0
  flutter_chat_kit: ^0.1.0
  lemsa_core_kit: ^1.1.0
```

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // slices
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
```

## Data layout

```text
rooms/{roomId}
  type: "direct" | "group" | "channel"
  title, avatar_url              (groups)
  member_ids: [uid, ...]         (for the inbox query)
  members: { uid: { role, last_read_at, last_delivered_at } }
  unread: { uid: 3, ... }        (maintained by a Cloud Function)
  pinned_by: [uid], muted_by: [uid]
  last_message: { ...message fields }
  updated_at: Timestamp

rooms/{roomId}/messages/{localId}
  ...fields written by MessageCodec (type, author_id, text, attachments, ...)
  created_at: Timestamp          (server timestamp)
  deleted_at: Timestamp?         (soft delete)

rooms/{roomId}/typing/{uid}
  typing: bool, at: Timestamp

status/{uid}                     (presence, mirrored from Realtime Database)
  online: bool, last_seen_at: Timestamp
```

Key choices:

- **The message document id is the `localId`.** A retried `send` writes the
  same document, so the outbox never duplicates messages. The adapter also
  uses the `localId` as the message `id`, which makes `(created_at, id)`
  cursors map directly to `orderBy('created_at').orderBy(documentId)`.
- **Soft delete.** Set `deleted_at` instead of deleting the document, so a
  deletion arrives as a normal `modified` change. A `removed` change in a
  windowed listener only means "left the window".
- **Unread counts** are incremented by a Cloud Function on message create
  (for every member except the author), and reset by `markRead`.

Composite indexes you will need:

| Collection | Fields |
| --- | --- |
| `rooms` | `member_ids` array-contains, `updated_at` desc, `__name__` desc |
| `messages` | `created_at` desc, `__name__` desc |

## Converting documents

`MessageCodec` accepts `DateTime`, ISO strings and epoch milliseconds, but
not Firestore `Timestamp`s, so convert them first.

```dart
Object? _plain(Object? value) => switch (value) {
  Timestamp t => t.toDate(),
  Map<Object?, Object?> m => {
    for (final e in m.entries) '${e.key}': _plain(e.value),
  },
  List<Object?> l => [for (final v in l) _plain(v)],
  _ => value,
};

const _codec = MessageCodec();

Message _message(DocumentSnapshot<Map<String, dynamic>> doc) {
  final json = _plain(doc.data()) as Map<String, Object?>;
  return _codec.decode({...json, 'id': doc.id, 'local_id': doc.id});
}

ChatRoom _room(DocumentSnapshot<Map<String, dynamic>> doc, String uid) {
  final json = _plain(doc.data()) as Map<String, Object?>;
  final members = (json['members'] as Map<String, Object?>? ?? {});
  return ChatRoom(
    id: doc.id,
    updatedAt: json['updated_at'] as DateTime? ?? DateTime.now().toUtc(),
    type: RoomType.parse(json['type']),
    title: json['title'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    members: [
      for (final MapEntry(:key, :value) in members.entries)
        RoomMember.fromJson({...value! as Map<String, Object?>, 'user_id': key}),
    ],
    lastMessage: switch (json['last_message']) {
      final Map<String, Object?> m => _codec.decode(m),
      _ => null,
    },
    unreadCount: ((json['unread'] as Map?)?[uid] as num?)?.toInt() ?? 0,
    pinned: (json['pinned_by'] as List?)?.contains(uid) ?? false,
    muted: (json['muted_by'] as List?)?.contains(uid) ?? false,
  );
}
```

## Errors

The kit only understands `AppFailure`. Network and timeout failures make the
outbox retry; everything else marks the message as failed.

```dart
AppFailure _failure(Object error) => switch (error) {
  AppFailure f => f,
  FirebaseException(code: 'unavailable') => NetworkFailure(cause: error),
  FirebaseException(code: 'deadline-exceeded') => TimeoutFailure(cause: error),
  FirebaseException(code: 'not-found') => NotFoundFailure('chat', cause: error),
  FirebaseException(code: 'permission-denied') =>
    PermissionFailure('chat', cause: error),
  FirebaseException(code: 'unauthenticated') =>
    AuthFailure(AuthReason.signedOut, cause: error),
  FirebaseException(code: 'already-exists') => ConflictFailure(cause: error),
  _ => UnknownFailure(cause: error),
};

Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on Object catch (e) {
    throw _failure(e);
  }
}
```

## The source

```dart
class FirestoreChatSource with ChatSourceDefaults {
  FirestoreChatSource(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> _messages(String roomId) =>
      _rooms.doc(roomId).collection('messages');

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
  }) => _guard(() async {
    var q = _rooms
        .where('member_ids', arrayContains: _uid)
        .orderBy('updated_at', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      q = q.startAfter([Timestamp.fromDate(after.updatedAt), after.id]);
    }
    final snap = await q.limit(limit + 1).get();
    var rooms = [for (final d in snap.docs.take(limit)) _room(d, _uid)];
    // Firestore has no substring search. Filter the page here, or back
    // search with Algolia / Typesense and return its results instead.
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      rooms = [
        for (final r in rooms)
          if ((r.title ?? '').toLowerCase().contains(s)) r,
      ];
    }
    return ChatPage(items: rooms, hasMore: snap.docs.length > limit);
  });

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) => _guard(() async {
    final newer = after != null;
    var q = _messages(roomId)
        .orderBy('created_at', descending: !newer)
        .orderBy(FieldPath.documentId, descending: !newer);
    if ((before ?? after) case final c?) {
      q = q.startAfter([Timestamp.fromDate(c.createdAt), c.id]);
    }
    final snap = await q.limit(limit + 1).get();
    final items = [for (final d in snap.docs.take(limit)) _message(d)];
    return ChatPage(
      // Pages are always newest first, even when reading forwards.
      items: newer ? items.reversed.toList() : items,
      hasMore: snap.docs.length > limit,
    );
  });

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) => _guard(() async {
    final target = await _messages(roomId).doc(messageId).get();
    if (!target.exists) throw const NotFoundFailure('message');
    final cursor = _message(target).cursor;
    final half = limit ~/ 2;
    final newer = await fetchMessages(roomId, after: cursor, limit: half);
    final older = await fetchMessages(roomId, before: cursor, limit: half);
    return ChatPage(
      items: [...newer.items, _message(target), ...older.items],
      hasMore: older.hasMore,
    );
  });

  @override
  Future<Message> send(Message pending) => _guard(() async {
    final ref = _messages(pending.roomId).doc(pending.localId);
    final existing = await ref.get();
    if (!existing.exists) {
      final data = pending.toJson()
        ..remove('status')
        ..['id'] = pending.localId
        ..['created_at'] = FieldValue.serverTimestamp();
      await (_db.batch()
            ..set(ref, data)
            ..update(_rooms.doc(pending.roomId), {
              'last_message': data,
              'updated_at': FieldValue.serverTimestamp(),
            }))
          .commit();
    }
    return _message(await ref.get());
  });

  @override
  Future<Message> edit(Message message) => _guard(() async {
    final ref = _messages(message.roomId).doc(message.localId);
    final data = message.toJson()
      ..removeWhere((k, _) => const {'created_at', 'status'}.contains(k))
      ..['edited_at'] = FieldValue.serverTimestamp();
    await ref.update(data);
    return _message(await ref.get());
  });

  @override
  Future<void> delete(String roomId, String messageId) => _guard(
    () => _messages(roomId).doc(messageId).update({
      'deleted_at': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) => _guard(
    () => _rooms.doc(roomId).update({
      'members.$_uid.last_read_at': Timestamp.fromDate(upTo.createdAt),
      'unread.$_uid': 0,
    }),
  );

  @override
  Future<void> setTyping(String roomId, {required bool typing}) => _guard(
    () => _rooms.doc(roomId).collection('typing').doc(_uid).set({
      'typing': typing,
      'at': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) => _guard(
    () => _messages(roomId).doc(messageId).update({
      'reactions.$emoji': add
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid]),
    }),
  );

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) => _guard(
    () => _rooms.doc(roomId).update({
      'pinned_by': pinned
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid]),
    }),
  );

  @override
  Future<void> setMuted(String roomId, {required bool muted}) => _guard(
    () => _rooms.doc(roomId).update({
      'muted_by': muted
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid]),
    }),
  );

  @override
  Stream<ChatEvent> events({String? roomId}) =>
      roomId == null ? _inboxEvents() : _roomEvents(roomId);
}
```

## Snapshots to `ChatEvent`

A room stream merges three listeners: the latest messages, typing, and the
room document (for read receipts). The first snapshot re-sends messages the
kit already has; that is fine, because the kit deduplicates by `localId`.

```dart
extension on FirestoreChatSource {
  Stream<ChatEvent> _roomEvents(String roomId) {
    final subs = <StreamSubscription<Object?>>[];
    late final StreamController<ChatEvent> out;
    void fail(Object e) => out.addError(_failure(e));

    out = StreamController<ChatEvent>(
      onListen: () {
        subs
          ..add(
            _messages(roomId)
                .orderBy('created_at', descending: true)
                .limit(50)
                .snapshots()
                .listen((snap) {
                  for (final c in snap.docChanges) {
                    // Local echo before the server timestamp resolves.
                    if (c.doc.data()?['created_at'] == null) continue;
                    if (c.type == DocumentChangeType.removed) continue;
                    final m = _message(c.doc);
                    out.add(
                      MessageChanged(
                        roomId: roomId,
                        change: c.type == DocumentChangeType.added
                            ? Created(m)
                            : Updated(m),
                      ),
                    );
                  }
                }, onError: fail),
          )
          ..add(
            _rooms.doc(roomId).collection('typing').snapshots().listen((snap) {
              for (final c in snap.docChanges) {
                if (c.doc.id == _uid) continue;
                out.add(
                  TypingChanged(
                    roomId: roomId,
                    userId: c.doc.id,
                    typing: c.doc.data()?['typing'] == true,
                  ),
                );
              }
            }, onError: fail),
          )
          ..add(
            _rooms.doc(roomId).snapshots().listen((doc) {
              if (!doc.exists) return;
              for (final m in _room(doc, _uid).members) {
                out.add(
                  ReceiptChanged(
                    roomId: roomId,
                    userId: m.userId,
                    readAt: m.lastReadAt,
                    deliveredAt: m.lastDeliveredAt,
                  ),
                );
              }
            }, onError: fail),
          );
      },
      onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
    );
    return out.stream;
  }

  Stream<ChatEvent> _inboxEvents() {
    return _rooms
        .where('member_ids', arrayContains: _uid)
        .orderBy('updated_at', descending: true)
        .limit(50)
        .snapshots()
        .expand(
          (snap) => [
            for (final c in snap.docChanges)
              if (c.type != DocumentChangeType.removed)
                RoomChanged(Updated(_room(c.doc, _uid))),
          ],
        )
        .handleError((Object e) => throw _failure(e));
  }
}
```

Presence: Firestore cannot detect disconnects. Use the Realtime Database
`onDisconnect()` pattern to write `status/{uid}`, mirror it to Firestore
with a Cloud Function, and add a `status` listener for the peers of the
loaded rooms to `_inboxEvents` that emits
`PresenceChanged(Presence(userId: ..., isOnline: ..., lastSeenAt: ...))`.

## Uploads with Firebase Storage

```dart
class StorageUploader implements ChatUploader {
  StorageUploader(this._storage);

  final FirebaseStorage _storage;

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    final ref = _storage.ref('chats/$roomId/$localId/${attachment.name ?? 'file'}');
    final meta = SettableMetadata(contentType: attachment.mimeType);
    // On web, local paths are blob URLs: read bytes and use putData.
    final task = ref.putFile(File(attachment.localPath!), meta);
    try {
      await for (final s in task.snapshotEvents) {
        if (s.totalBytes > 0) yield UploadRunning(s.bytesTransferred / s.totalBytes);
        if (s.state == TaskState.success) break;
      }
      yield UploadDone(remoteUrl: await ref.getDownloadURL());
    } on Object catch (e) {
      throw _failure(e);
    }
  }
}
```

## Users

```dart
class FirestoreUserResolver implements ChatUserResolver {
  FirestoreUserResolver(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<ChatUser>> resolve(Set<String> ids) async {
    final users = <ChatUser>[];
    // whereIn accepts at most 30 values per query.
    for (final chunk in ids.slices(30)) {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        users.add(
          ChatUser(
            id: d.id,
            name: d.data()['name'] as String? ?? '',
            avatarUrl: d.data()['avatar_url'] as String?,
          ),
        );
      }
    }
    return users;
  }
}
```

(`slices` comes from `package:collection`.)

## Wiring

```dart
final kit = ChatKit(
  currentUserId: FirebaseAuth.instance.currentUser!.uid,
  source: FirestoreChatSource(FirebaseFirestore.instance, uid),
  uploader: StorageUploader(FirebaseStorage.instance),
  users: FirestoreUserResolver(FirebaseFirestore.instance),
);
await kit.open();
```

Firestore keeps its own offline cache. You can keep it, but the kit already
caches rooms and messages in SQLite, so disabling Firestore persistence
(`Settings(persistenceEnabled: false)`) avoids storing everything twice.
