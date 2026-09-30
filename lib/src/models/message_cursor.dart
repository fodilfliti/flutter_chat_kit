import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// Keyset position in a room's history.
///
/// Messages are totally ordered by [createdAt], then [id], so two messages
/// with the same timestamp still page correctly.
@immutable
class MessageCursor implements Comparable<MessageCursor> {
  const MessageCursor(this.createdAt, this.id);

  factory MessageCursor.fromJson(Map<String, Object?> json) {
    return MessageCursor(
      readRequiredDate(json, 'created_at'),
      readString(json, 'id'),
    );
  }

  final DateTime createdAt;
  final String id;

  @override
  int compareTo(MessageCursor other) {
    final byTime = createdAt.compareTo(other.createdAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }

  bool isAfter(MessageCursor other) => compareTo(other) > 0;

  bool isBefore(MessageCursor other) => compareTo(other) < 0;

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
@immutable
class RoomCursor implements Comparable<RoomCursor> {
  const RoomCursor(this.updatedAt, this.id);

  factory RoomCursor.fromJson(Map<String, Object?> json) {
    return RoomCursor(
      readRequiredDate(json, 'updated_at'),
      readString(json, 'id'),
    );
  }

  final DateTime updatedAt;
  final String id;

  @override
  int compareTo(RoomCursor other) {
    final byTime = updatedAt.compareTo(other.updatedAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }

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
