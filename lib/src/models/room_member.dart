import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message.dart';

enum MemberRole {
  owner,
  admin,
  member;

  static MemberRole parse(Object? value) {
    if (value is! String) return MemberRole.member;
    return MemberRole.values.asNameMap()[value] ?? MemberRole.member;
  }
}

/// A user's membership in a room, including read pointers.
///
/// Receipts are derived from [lastReadAt] / [lastDeliveredAt]: a message is
/// seen by this member when its `createdAt` is not after [lastReadAt].
@immutable
class RoomMember {
  const RoomMember({
    required this.userId,
    this.role = MemberRole.member,
    this.lastReadAt,
    this.lastDeliveredAt,
  });

  /// Reads a member object, or a plain user id.
  factory RoomMember.fromJson(
    Object? json, {
    MemberJsonKeys keys = const MemberJsonKeys(),
  }) {
    if (json is String || json is num) return RoomMember(userId: '$json');
    final map = readMap(json);
    final userId = readOptionalString(map[keys.userId]);
    if (userId == null) {
      throw FormatException(
        'Room member needs "${keys.userId}"; set MemberJsonKeys(userId: ...) '
        'if your API names it differently. Got the fields '
        '${map.keys.toList()}.',
      );
    }
    return RoomMember(
      userId: userId,
      role: MemberRole.parse(map[keys.role]),
      lastReadAt: readDate(map[keys.lastReadAt]),
      lastDeliveredAt: readDate(map[keys.lastDeliveredAt]),
    );
  }

  final String userId;
  final MemberRole role;
  final DateTime? lastReadAt;
  final DateTime? lastDeliveredAt;

  bool hasRead(Message message) {
    final readAt = lastReadAt;
    return readAt != null && !message.createdAt.isAfter(readAt);
  }

  bool hasReceived(Message message) {
    if (hasRead(message)) return true;
    final deliveredAt = lastDeliveredAt;
    return deliveredAt != null && !message.createdAt.isAfter(deliveredAt);
  }

  RoomMember copyWith({
    String? userId,
    MemberRole? role,
    DateTime? lastReadAt,
    DateTime? lastDeliveredAt,
  }) {
    return RoomMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastDeliveredAt: lastDeliveredAt ?? this.lastDeliveredAt,
    );
  }

  Map<String, Object?> toJson({MemberJsonKeys keys = const MemberJsonKeys()}) {
    return withoutNulls({
      keys.userId: userId,
      keys.role: role.name,
      keys.lastReadAt: writeDate(lastReadAt),
      keys.lastDeliveredAt: writeDate(lastDeliveredAt),
    });
  }

  @override
  bool operator ==(Object other) {
    return other is RoomMember &&
        other.userId == userId &&
        other.role == role &&
        other.lastReadAt == lastReadAt &&
        other.lastDeliveredAt == lastDeliveredAt;
  }

  @override
  int get hashCode => Object.hash(userId, role, lastReadAt, lastDeliveredAt);

  @override
  String toString() => 'RoomMember($userId, ${role.name})';
}
