import 'package:flutter/foundation.dart';

/// Online state of a user, when the backend supports it.
///
/// Sent with `PresenceChanged`. Direct rooms show an online dot on the
/// avatar and "online" or "last seen ..." in the app bar. Presence is never
/// cached: until an event arrives, nothing is shown.
@immutable
class Presence {
  /// The state of [userId]; [lastSeenAt] is optional.
  const Presence({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });

  /// The user this state belongs to.
  final String userId;

  /// Whether the user is online now.
  final bool isOnline;

  /// When the user was last online, shown as "last seen ..." while
  /// offline. Without it the app bar shows nothing while offline.
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
