import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';

/// Who is currently typing in a room (never cached).
///
/// Built by the kit from `TypingChanged` events; the current user is never
/// included.
@immutable
class TypingState {
  /// [userIds] typing in [roomId].
  const TypingState({required this.roomId, this.userIds = const {}});

  /// The room.
  final String roomId;

  /// The ids of the users typing now.
  final Set<String> userIds;

  /// Whether nobody is typing.
  bool get isEmpty => userIds.isEmpty;

  /// A copy with [userId] added when [typing], else removed.
  TypingState withUser(String userId, {required bool typing}) {
    final next = {...userIds};
    if (typing) {
      next.add(userId);
    } else {
      next.remove(userId);
    }
    return TypingState(roomId: roomId, userIds: next);
  }

  @override
  bool operator ==(Object other) {
    return other is TypingState &&
        other.roomId == roomId &&
        deepEquality.equals(other.userIds, userIds);
  }

  @override
  int get hashCode => Object.hash(roomId, deepEquality.hash(userIds));

  @override
  String toString() => 'TypingState($roomId, $userIds)';
}
