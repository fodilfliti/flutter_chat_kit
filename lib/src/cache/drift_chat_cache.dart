import 'package:drift/drift.dart';
import 'package:flutter_chat_kit/src/cache/chat_cache.dart';
import 'package:flutter_chat_kit/src/cache/drift/chat_database.dart';
import 'package:flutter_chat_kit/src/cache/drift/converters.dart';
import 'package:flutter_chat_kit/src/cache/drift/open_chat_database.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';
import 'package:flutter_chat_kit/src/sync/outbox_entry.dart';
import 'package:flutter_chat_kit/src/sync/room_sync_state.dart';

export 'package:flutter_chat_kit/src/cache/drift/open_chat_database.dart'
    show chatDatabaseName, openChatDatabase;

/// Creates the database connection for a user id.
typedef ChatExecutorFactory = QueryExecutor Function(String userId);

/// Default [ChatCache]: SQLite through Drift, one database per user.
///
/// Tests pass `executorFactory: (_) => NativeDatabase.memory()`.
class DriftChatCache implements ChatCache {
  DriftChatCache({
    this._executorFactory = openChatDatabase,
    this._clock = DateTime.now,
  });

  final ChatExecutorFactory _executorFactory;
  final DateTime Function() _clock;
  ChatDatabase? _database;
  String? _userId;

  static final List<String> _localStatuses = [
    for (final s in MessageStatus.values)
      if (s.isLocal) s.name,
  ];

  ChatDatabase get _db =>
      _database ?? (throw StateError('ChatCache is not open'));

  @override
  bool get isOpen => _database != null;

  @override
  Future<void> open(String userId) async {
    if (_database != null && _userId == userId) return;
    await close();
    _database = ChatDatabase(_executorFactory(userId));
    _userId = userId;
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    _userId = null;
    await db?.close();
  }

  @override
  Future<void> clear() => _db.deleteUserData();

  @override
  Stream<List<ChatRoom>> watchRooms({String? search}) {
    final db = _db;
    final query = _roomsQuery(db);
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      final pattern = '%${_escapeLike(term)}%';
      final m = db.alias(db.members, 'search_members');
      final u = db.alias(db.users, 'search_users');
      final byMemberName =
          db.selectOnly(m).join([innerJoin(u, u.id.equalsExp(m.userId))])
            ..where(
              m.roomId.equalsExp(db.rooms.id) &
                  u.name.like(pattern, escapeChar: r'\'),
            );
      byMemberName.addColumns([m.userId]);
      query.where(
        db.rooms.title.like(pattern, escapeChar: r'\') |
            existsQuery(byMemberName),
      );
    }
    return query.watch().map((rows) => _groupRooms(db, rows));
  }

  @override
  Stream<ChatRoom?> watchRoom(String roomId) {
    final db = _db;
    final query = _roomsQuery(db)..where(db.rooms.id.equals(roomId));
    return query.watch().map((rows) {
      final rooms = _groupRooms(db, rows);
      return rooms.isEmpty ? null : rooms.first;
    });
  }

  JoinedSelectStatement<HasResultSet, dynamic> _roomsQuery(ChatDatabase db) {
    return db.select(db.rooms).join([
      leftOuterJoin(db.members, db.members.roomId.equalsExp(db.rooms.id)),
    ])..orderBy([
      OrderingTerm.desc(db.rooms.pinned),
      OrderingTerm.desc(db.rooms.updatedAt),
      OrderingTerm.asc(db.rooms.id),
      OrderingTerm.asc(db.members.userId),
    ]);
  }

  List<ChatRoom> _groupRooms(ChatDatabase db, List<TypedResult> rows) {
    final rooms = <String, RoomRow>{};
    final members = <String, List<RoomMember>>{};
    for (final row in rows) {
      final room = row.readTable(db.rooms);
      rooms.putIfAbsent(room.id, () => room);
      final member = row.readTableOrNull(db.members);
      if (member != null) {
        (members[room.id] ??= []).add(memberFromRow(member));
      }
    }
    return [
      for (final room in rooms.values)
        roomFromRow(room, members[room.id] ?? const []),
    ];
  }

  @override
  Stream<List<Message>> watchMessages(
    String roomId, {
    MessageCursor? from,
    MessageCursor? to,
    int? limit,
  }) {
    return _rangeQuery(roomId, from, to, limit).watch().map(_toMessages);
  }

  @override
  Future<List<Message>> messages(
    String roomId, {
    MessageCursor? from,
    MessageCursor? to,
    int? limit,
  }) async {
    return _toMessages(await _rangeQuery(roomId, from, to, limit).get());
  }

  SimpleSelectStatement<$MessagesTable, MessageRow> _rangeQuery(
    String roomId,
    MessageCursor? from,
    MessageCursor? to,
    int? limit,
  ) {
    final db = _db;
    final query = db.select(db.messages)
      ..where((t) => t.roomId.equals(roomId))
      ..orderBy(_newestFirst);
    if (from != null) query.where((t) => _before(t, from).not());
    if (to != null) query.where((t) => _after(t, to).not());
    if (limit != null) query.limit(limit);
    return query;
  }

  @override
  Stream<List<RoomMember>> watchMembers(String roomId) {
    final db = _db;
    final query = db.select(db.members)
      ..where((t) => t.roomId.equals(roomId))
      ..orderBy([(t) => OrderingTerm.asc(t.userId)]);
    return query.watch().map((rows) => rows.map(memberFromRow).toList());
  }

  @override
  Future<List<Message>> messagesBefore(
    String roomId,
    MessageCursor cursor,
    int limit,
  ) async {
    final db = _db;
    final rows =
        await (db.select(db.messages)
              ..where((t) => t.roomId.equals(roomId) & _before(t, cursor))
              ..orderBy(_newestFirst)
              ..limit(limit))
            .get();
    return _toMessages(rows);
  }

  @override
  Future<List<Message>> messagesAfter(
    String roomId,
    MessageCursor cursor,
    int limit,
  ) async {
    final db = _db;
    final rows =
        await (db.select(db.messages)
              ..where((t) => t.roomId.equals(roomId) & _after(t, cursor))
              ..orderBy(_oldestFirst)
              ..limit(limit))
            .get();
    return _toMessages(rows.reversed);
  }

  @override
  Future<Message?> messageByAnyId(String idOrLocalId) async {
    final db = _db;
    final row =
        await (db.select(db.messages)
              ..where(
                (t) => t.localId.equals(idOrLocalId) | t.id.equals(idOrLocalId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : messageFromRow(row);
  }

  @override
  Future<void> upsertRooms(List<ChatRoom> rooms) {
    final db = _db;
    return db.transaction(() async {
      for (final room in rooms) {
        await db.into(db.rooms).insertOnConflictUpdate(roomToRow(room));
        if (room.members.isEmpty) continue;
        final ids = room.members.map((m) => m.userId).toList();
        await (db.delete(
          db.members,
        )..where((t) => t.roomId.equals(room.id) & t.userId.isNotIn(ids))).go();
        for (final member in room.members) {
          await _upsertMember(db, room.id, member);
        }
      }
    });
  }

  @override
  Future<void> deleteRoom(String roomId) {
    final db = _db;
    return db.transaction(() async {
      await (db.delete(db.rooms)..where((t) => t.id.equals(roomId))).go();
      await (db.delete(db.members)..where((t) => t.roomId.equals(roomId))).go();
      await (db.delete(
        db.messages,
      )..where((t) => t.roomId.equals(roomId))).go();
      await (db.delete(
        db.roomSyncStates,
      )..where((t) => t.roomId.equals(roomId))).go();
      await (db.delete(db.drafts)..where((t) => t.roomId.equals(roomId))).go();
      await (db.delete(db.outbox)..where((t) => t.roomId.equals(roomId))).go();
    });
  }

  @override
  Future<void> upsertMessages(List<Message> messages) {
    if (messages.isEmpty) return Future.value();
    final db = _db;
    return db.transaction(() async {
      for (final message in messages) {
        await _upsertMessage(db, message);
      }
    });
  }

  Future<void> _upsertMessage(ChatDatabase db, Message message) async {
    final existing =
        await (db.select(db.messages)..where(
              (t) =>
                  t.localId.equals(message.localId) | t.id.equals(message.id),
            ))
            .get();
    final row = messageToRow(message);
    if (existing.isEmpty) {
      await db.into(db.messages).insert(row);
      return;
    }
    // Keep the row the UI already knows (same localId); drop any duplicate
    // that holds the server id.
    final keeper = existing.firstWhere(
      (r) => r.localId == message.localId,
      orElse: () => existing.first,
    );
    for (final other in existing) {
      if (other.localId == keeper.localId) continue;
      await (db.delete(
        db.messages,
      )..where((t) => t.localId.equals(other.localId))).go();
    }
    await (db.update(db.messages)
          ..where((t) => t.localId.equals(keeper.localId)))
        .write(row.copyWith(localId: Value(keeper.localId)));
  }

  @override
  Future<void> deleteMessage(String idOrLocalId) async {
    final db = _db;
    await (db.delete(db.messages)..where(
          (t) => t.localId.equals(idOrLocalId) | t.id.equals(idOrLocalId),
        ))
        .go();
  }

  @override
  Future<void> upsertMembers(String roomId, List<RoomMember> members) {
    final db = _db;
    return db.transaction(() async {
      for (final member in members) {
        await _upsertMember(db, roomId, member);
      }
    });
  }

  @override
  Future<void> updatePointers(
    String roomId,
    String userId, {
    DateTime? readAt,
    DateTime? deliveredAt,
  }) {
    final db = _db;
    return db.transaction(() async {
      final existing =
          await (db.select(db.members)..where(
                (t) => t.roomId.equals(roomId) & t.userId.equals(userId),
              ))
              .getSingleOrNull();
      await _upsertMember(
        db,
        roomId,
        RoomMember(
          userId: userId,
          role: existing == null
              ? MemberRole.member
              : MemberRole.parse(existing.role),
          lastReadAt: readAt,
          lastDeliveredAt: deliveredAt,
        ),
      );
    });
  }

  Future<void> _upsertMember(
    ChatDatabase db,
    String roomId,
    RoomMember member,
  ) async {
    final existing =
        await (db.select(db.members)..where(
              (t) => t.roomId.equals(roomId) & t.userId.equals(member.userId),
            ))
            .getSingleOrNull();
    var row = memberToRow(roomId, member);
    if (existing != null) {
      row = row.copyWith(
        lastReadAt: Value(_max(existing.lastReadAt, row.lastReadAt.value)),
        lastDeliveredAt: Value(
          _max(existing.lastDeliveredAt, row.lastDeliveredAt.value),
        ),
      );
    }
    await db.into(db.members).insertOnConflictUpdate(row);
  }

  @override
  Future<void> upsertUsers(List<ChatUser> users) {
    if (users.isEmpty) return Future.value();
    final db = _db;
    final now = _clock();
    return db.batch((b) {
      b.insertAllOnConflictUpdate(db.users, [
        for (final user in users) userToRow(user, now),
      ]);
    });
  }

  @override
  Future<Map<String, ChatUser>> users(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final db = _db;
    final rows = await (db.select(
      db.users,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final row in rows) row.id: userFromRow(row)};
  }

  @override
  Future<Set<String>> staleUsers(
    Set<String> ids, {
    required DateTime olderThan,
  }) async {
    if (ids.isEmpty) return const {};
    final db = _db;
    final fresh =
        await (db.selectOnly(db.users)
              ..addColumns([db.users.id])
              ..where(
                db.users.id.isIn(ids) &
                    db.users.fetchedAt.isBiggerOrEqualValue(
                      toMicros(olderThan),
                    ),
              ))
            .map((row) => row.read(db.users.id)!)
            .get();
    return ids.difference(fresh.toSet());
  }

  @override
  Future<RoomSyncState?> syncState(String roomId) async {
    final db = _db;
    final row = await (db.select(
      db.roomSyncStates,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    return row == null ? null : syncStateFromRow(row);
  }

  @override
  Future<void> saveSyncState(RoomSyncState state) async {
    final db = _db;
    await db
        .into(db.roomSyncStates)
        .insertOnConflictUpdate(syncStateToRow(state));
  }

  @override
  Future<void> enqueue(OutboxEntry entry) async {
    final db = _db;
    await db.into(db.outbox).insertOnConflictUpdate(outboxToRow(entry));
  }

  @override
  Future<List<OutboxEntry>> dueOutbox(DateTime now) async {
    final db = _db;
    final at = toMicros(now);
    final rows =
        await (db.select(db.outbox)
              ..where(
                (t) =>
                    t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(at),
              )
              ..orderBy(_outboxOrder))
            .get();
    return rows.map(outboxFromRow).toList();
  }

  @override
  Future<List<OutboxEntry>> outbox() async {
    final db = _db;
    final rows = await (db.select(db.outbox)..orderBy(_outboxOrder)).get();
    return rows.map(outboxFromRow).toList();
  }

  @override
  Future<OutboxEntry?> outboxEntry(String key) async {
    final db = _db;
    final row = await (db.select(
      db.outbox,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : outboxFromRow(row);
  }

  @override
  Future<void> updateOutbox(OutboxEntry entry) => enqueue(entry);

  @override
  Future<void> removeOutbox(String key) async {
    final db = _db;
    await (db.delete(db.outbox)..where((t) => t.key.equals(key))).go();
  }

  @override
  Future<void> stage(
    Message message, {
    OutboxEntry? enqueue,
    List<String> removeKeys = const [],
  }) {
    final db = _db;
    return db.transaction(() async {
      await _upsertMessage(db, message);
      if (enqueue != null) {
        await db.into(db.outbox).insertOnConflictUpdate(outboxToRow(enqueue));
      }
      if (removeKeys.isNotEmpty) {
        await (db.delete(db.outbox)..where((t) => t.key.isIn(removeKeys))).go();
      }
    });
  }

  @override
  Future<ChatDraft?> draft(String roomId) async {
    final db = _db;
    final row = await (db.select(
      db.drafts,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    return row == null
        ? null
        : ChatDraft(text: row.body, replyToId: row.replyToId);
  }

  @override
  Future<void> saveDraft(
    String roomId,
    String? text, {
    String? replyToId,
  }) async {
    final db = _db;
    if ((text == null || text.isEmpty) && replyToId == null) {
      await (db.delete(db.drafts)..where((t) => t.roomId.equals(roomId))).go();
      return;
    }
    await db
        .into(db.drafts)
        .insertOnConflictUpdate(
          DraftsCompanion.insert(
            roomId: roomId,
            body: text ?? '',
            replyToId: Value(replyToId),
            updatedAt: toMicros(_clock()),
          ),
        );
  }

  @override
  Future<void> trim(String roomId, {required int keep}) {
    final db = _db;
    return db.transaction(() async {
      final boundary =
          await (db.select(db.messages)
                ..where(
                  (t) =>
                      t.roomId.equals(roomId) &
                      t.status.isNotIn(_localStatuses),
                )
                ..orderBy(_newestFirst)
                ..limit(1, offset: keep < 1 ? 0 : keep - 1))
              .getSingleOrNull();
      if (boundary == null) return;
      final cursor = MessageCursor(fromMicros(boundary.createdAt), boundary.id);
      await (db.delete(db.messages)..where(
            (t) =>
                t.roomId.equals(roomId) &
                t.status.isNotIn(_localStatuses) &
                (keep < 1 ? const Constant(true) : _before(t, cursor)),
          ))
          .go();
      final state = await syncState(roomId);
      if (state != null) {
        await saveSyncState(
          RoomSyncState(
            roomId: roomId,
            newest: keep < 1 ? null : state.newest,
            oldest: keep < 1 ? null : cursor,
            syncedAt: state.syncedAt,
          ),
        );
      }
    });
  }

  /// Oldest first; ties keep insertion order (an upsert keeps its rowid).
  static final _outboxOrder = <OrderClauseGenerator<$OutboxTable>>[
    (t) => OrderingTerm.asc(t.createdAt),
    (t) => OrderingTerm.asc(t.rowId),
  ];

  static final _newestFirst = <OrderClauseGenerator<$MessagesTable>>[
    (t) => OrderingTerm.desc(t.createdAt),
    (t) => OrderingTerm.desc(t.id),
  ];

  static final _oldestFirst = <OrderClauseGenerator<$MessagesTable>>[
    (t) => OrderingTerm.asc(t.createdAt),
    (t) => OrderingTerm.asc(t.id),
  ];

  static Expression<bool> _before($MessagesTable t, MessageCursor c) {
    final at = toMicros(c.createdAt);
    return t.createdAt.isSmallerThanValue(at) |
        (t.createdAt.equals(at) & t.id.isSmallerThanValue(c.id));
  }

  static Expression<bool> _after($MessagesTable t, MessageCursor c) {
    final at = toMicros(c.createdAt);
    return t.createdAt.isBiggerThanValue(at) |
        (t.createdAt.equals(at) & t.id.isBiggerThanValue(c.id));
  }

  static List<Message> _toMessages(Iterable<MessageRow> rows) =>
      rows.map(messageFromRow).toList();

  static int? _max(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
