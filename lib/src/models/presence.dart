import 'package:flutter/foundation.dart';

/// Online state of a user, when the backend supports it.
@immutable
class Presence {
  const Presence({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });

  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  @override
  bool operator ==(Object other) {
    return other is Presence &&
        other.userId == userId &&
        other.isOnline == isOnline &&
        other.lastSeenAt == lastSeenAt;
  }

  @override
  int get hashCode => Object.hash(userId, isOnline, lastSeenAt);

  @override
  String toString() => 'Presence($userId, online: $isOnline)';
}
