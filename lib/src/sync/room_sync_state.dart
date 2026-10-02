import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';

/// What the cache holds for one room, so sync resumes from the right place.
@immutable
class RoomSyncState {
  const RoomSyncState({
    required this.roomId,
    this.newest,
    this.oldest,
    this.hasMoreOlder = true,
    this.syncedAt,
  });

  final String roomId;

  /// Newest message fetched from the source; gap fill starts after it.
  final MessageCursor? newest;

  /// Oldest message loaded; older pages start before it.
  final MessageCursor? oldest;

  /// False once the source reported the start of the conversation.
  final bool hasMoreOlder;
  final DateTime? syncedAt;

  RoomSyncState copyWith({
    MessageCursor? newest,
    MessageCursor? oldest,
    bool? hasMoreOlder,
    DateTime? syncedAt,
  }) {
    return RoomSyncState(
      roomId: roomId,
      newest: newest ?? this.newest,
      oldest: oldest ?? this.oldest,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoomSyncState &&
      other.roomId == roomId &&
      other.newest == newest &&
      other.oldest == oldest &&
      other.hasMoreOlder == hasMoreOlder &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode =>
      Object.hash(roomId, newest, oldest, hasMoreOlder, syncedAt);

  @override
  String toString() =>
      'RoomSyncState($roomId, newest: $newest, oldest: $oldest, '
      'hasMoreOlder: $hasMoreOlder)';
}
