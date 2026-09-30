import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// A write waiting to reach the source.
enum OutboxOp {
  send,
  edit,
  delete,
  react;

  static OutboxOp parse(String value) =>
      values.firstWhere((op) => op.name == value, orElse: () => send);
}

/// One persisted outbox row. Survives restarts.
@immutable
class OutboxEntry {
  const OutboxEntry({
    required this.key,
    required this.localId,
    required this.roomId,
    required this.op,
    required this.createdAt,
    this.payload = const {},
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  /// Unique per pending write, for example `send:<localId>` or
  /// `react:<localId>:<emoji>`, so a message can have several entries.
  final String key;

  /// Local id of the message the write targets.
  final String localId;
  final String roomId;
  final OutboxOp op;
  final DateTime createdAt;
  final Map<String, Object?> payload;
  final int attempts;

  /// Not retried before this time. Null means due now.
  final DateTime? nextAttemptAt;
  final String? lastError;

  OutboxEntry copyWith({
    Map<String, Object?>? payload,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
  }) {
    return OutboxEntry(
      key: key,
      localId: localId,
      roomId: roomId,
      op: op,
      createdAt: createdAt,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OutboxEntry &&
      other.key == key &&
      other.localId == localId &&
      other.roomId == roomId &&
      other.op == op &&
      other.createdAt == createdAt &&
      deepEquality.equals(other.payload, payload) &&
      other.attempts == attempts &&
      other.nextAttemptAt == nextAttemptAt &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(
    key,
    localId,
    roomId,
    op,
    createdAt,
    deepEquality.hash(payload),
    attempts,
    nextAttemptAt,
    lastError,
  );

  @override
  String toString() => 'OutboxEntry($key, ${op.name}, attempts: $attempts)';
}
