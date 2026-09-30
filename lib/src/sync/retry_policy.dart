import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// When and how often the outbox retries a write.
///
/// Attempt `n` (1-based) waits `base * 2^(n-1)`, capped at [max], then
/// spread by up to ±[jitter] of itself so clients don't retry in lockstep.
@immutable
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 5,
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 2),
    this.jitter = 0.2,
  }) : assert(maxAttempts > 0, 'maxAttempts must be positive'),
       assert(jitter >= 0 && jitter <= 1, 'jitter must be within 0..1');

  /// Attempts before a send is marked failed, the first one included.
  final int maxAttempts;
  final Duration base;
  final Duration max;

  /// Fraction of the delay added or removed at random.
  final double jitter;

  /// Whether [failure] is worth retrying automatically: connectivity
  /// problems are, rejections are not.
  bool isRetryable(AppFailure failure) =>
      failure is NetworkFailure || failure is TimeoutFailure;

  /// Delay before the next try after [attempt] failed tries.
  Duration delay(int attempt, {math.Random? random}) {
    final exponent = math.max(0, attempt - 1).clamp(0, 30);
    final raw = base.inMicroseconds * math.pow(2, exponent);
    final capped = math.min(raw, max.inMicroseconds.toDouble());
    if (jitter == 0) return Duration(microseconds: capped.round());
    final spread = ((random ?? _random).nextDouble() * 2 - 1) * jitter;
    return Duration(microseconds: (capped * (1 + spread)).round());
  }

  static final _random = math.Random();

  @override
  bool operator ==(Object other) =>
      other is RetryPolicy &&
      other.maxAttempts == maxAttempts &&
      other.base == base &&
      other.max == max &&
      other.jitter == jitter;

  @override
  int get hashCode => Object.hash(maxAttempts, base, max, jitter);
}
