import 'package:drift/drift.dart';
import 'package:flutter_chat_kit/src/cache/drift/tables.dart';

part 'chat_database.g.dart';

/// The kit's SQLite schema. One instance per signed-in user.
@DriftDatabase(
  tables: [Rooms, Members, Users, Messages, Outbox, RoomSyncStates, Drafts],
)
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  /// Wipes every table (sign-out / account switch).
  Future<void> deleteUserData() {
    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
