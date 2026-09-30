import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// Who is currently typing in a room (never cached).
@immutable
class TypingState {
  const TypingState({required this.roomId, this.userIds = const {}});

  final String roomId;
  final Set<String> userIds;

  bool get isEmpty => userIds.isEmpty;

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
