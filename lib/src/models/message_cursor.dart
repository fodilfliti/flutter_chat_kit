import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// Keyset position in a room's history.
///
/// Messages are totally ordered by [createdAt], then [id], so two messages
/// with the same timestamp still page correctly. `ChatSource.fetchMessages`
/// receives cursors as exclusive bounds: return messages strictly before
/// (or after) the cursor, never the message at the cursor itself.
///
/// ```dart
/// // SQL: WHERE (created_at, id) < (:createdAt, :id)
/// //      ORDER BY created_at DESC, id DESC LIMIT :limit
/// final query = {
///   'before_time': before.createdAt.toIso8601String(),
///   'before_id': before.id,
/// };
/// ```
@immutable
class MessageCursor implements Comparable<MessageCursor> {
  /// The position of the message created at [createdAt] with [id].
  const MessageCursor(this.createdAt, this.id);

  /// Reads `{"created_at": ..., "id": ...}`; both are required and the
  /// names are fixed. Throws a [FormatException] when one is missing.
  factory MessageCursor.fromJson(Map<String, Object?> json) {
    return MessageCursor(
      readRequiredDate(json, 'created_at'),
      readString(json, 'id'),
    );
  }

  /// The message time, in UTC.
  final DateTime createdAt;

  /// The message id, which breaks ties between equal times.
  final String id;

  @override
  int compareTo(MessageCursor other) {
    final byTime = createdAt.compareTo(other.createdAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }

  /// Whether this position is newer than [other].
  bool isAfter(MessageCursor other) => compareTo(other) > 0;

  /// Whether this position is older than [other].
  bool isBefore(MessageCursor other) => compareTo(other) < 0;

  /// `{"created_at": <ISO-8601 UTC>, "id": ...}`.
  Map<String, Object?> toJson() => {
    'created_at': writeDate(createdAt),
    'id': id,
  };

  @override
  bool operator ==(Object other) {
    return other is MessageCursor &&
        other.createdAt == createdAt &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(createdAt, id);

  @override
  String toString() => 'MessageCursor(${writeDate(createdAt)}, $id)';
}

/// Keyset position in the room list, ordered by [updatedAt] then [id].
///
/// `ChatSource.fetchRooms(after:)` receives it as an exclusive bound: return
/// rooms older than the cursor, newest first.
@immutable
class RoomCursor implements Comparable<RoomCursor> {
  /// The position of the room last active at [updatedAt] with [id].
  const RoomCursor(this.updatedAt, this.id);

  /// Reads `{"updated_at": ..., "id": ...}`; both are required and the
  /// names are fixed. Throws a [FormatException] when one is missing.
  factory RoomCursor.fromJson(Map<String, Object?> json) {
    return RoomCursor(
      readRequiredDate(json, 'updated_at'),
      readString(json, 'id'),
    );
  }

  /// The room's last activity, in UTC.
  final DateTime updatedAt;

  /// The room id, which breaks ties between equal times.
  final String id;

  @override
  int compareTo(RoomCursor other) {
    final byTime = updatedAt.compareTo(other.updatedAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }

  /// `{"updated_at": <ISO-8601 UTC>, "id": ...}`.
  Map<String, Object?> toJson() => {
    'updated_at': writeDate(updatedAt),
    'id': id,
  };

  @override
  bool operator ==(Object other) {
    return other is RoomCursor &&
        other.updatedAt == updatedAt &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(updatedAt, id);

  @override
  String toString() => 'RoomCursor(${writeDate(updatedAt)}, $id)';
}
