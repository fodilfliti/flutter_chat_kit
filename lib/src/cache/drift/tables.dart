import 'package:drift/drift.dart';

// Timestamps are UTC microseconds since epoch: exact, so keyset cursors
// round-trip, and sortable.

@TableIndex(name: 'rooms_order', columns: {#pinned, #updatedAt, #id})
@DataClassName('RoomRow')
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get lastMessageJson => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MemberRow')
class Members extends Table {
  TextColumn get roomId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text()();
  IntColumn get lastReadAt => integer().nullable()();
  IntColumn get lastDeliveredAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {roomId, userId};
}

@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'messages_room_order', columns: {#roomId, #createdAt, #id})
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get localId => text()();
  TextColumn get id => text().unique()();
  TextColumn get roomId => text()();
  TextColumn get authorId => text()();
  TextColumn get type => text()();
  IntColumn get createdAt => integer()();
  IntColumn get editedAt => integer().nullable()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get replyToId => text().nullable()();

  /// Subtype fields (text, attachments, ...) in the kit's own JSON format.
  TextColumn get bodyJson => text()();
  TextColumn get reactionsJson => text().withDefault(const Constant('{}'))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@TableIndex(name: 'outbox_due', columns: {#nextAttemptAt})
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get key => text()();
  TextColumn get localId => text()();
  TextColumn get roomId => text()();
  TextColumn get op => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('SyncStateRow')
class RoomSyncStates extends Table {
  TextColumn get roomId => text()();
  IntColumn get newestCreatedAt => integer().nullable()();
  TextColumn get newestId => text().nullable()();
  IntColumn get oldestCreatedAt => integer().nullable()();
  TextColumn get oldestId => text().nullable()();
  BoolColumn get hasMoreOlder => boolean().withDefault(const Constant(true))();
  IntColumn get syncedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {roomId};
}

@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get roomId => text()();
  TextColumn get body => text()();
  TextColumn get replyToId => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {roomId};
}
