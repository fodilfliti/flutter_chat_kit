/// How far the server's clock is from this device's, learned from
/// confirmed sends.
///
/// A phone set ten minutes ahead would stamp pending messages in the
/// future: they sort below replies that arrive meanwhile, then jump when
/// the server confirms them. Each confirmed send gives one estimate, the
/// server's `createdAt` minus the middle of the request on this device;
/// [offset] is the median of the last [samples] estimates, so one slow
/// request doesn't move it.
class ServerClock {
  ServerClock({
    this._clock = DateTime.now,
    this.samples = 5,
    this.maxRoundTrip = const Duration(seconds: 10),
  }) : assert(samples > 0, 'samples must be positive');

  final DateTime Function() _clock;

  /// Estimates kept for the median.
  final int samples;

  /// Requests slower than this are ignored: the midpoint could be off by
  /// half of it.
  final Duration maxRoundTrip;

  final List<Duration> _estimates = [];
  Duration _offset = Duration.zero;

  /// Server time minus device time. Zero until the first confirmed send.
  Duration get offset => _offset;

  /// The device clock corrected by [offset].
  DateTime now() => _clock().add(_offset);

  /// Records a send that left at [sentAt] and was answered at
  /// [answeredAt] (device times) with the server's [serverTime].
  ///
  /// Skipped when [serverTime] equals [clientTime], the time the message
  /// was sent with: that backend keeps the client's time, and learning
  /// from it would make the offset drift.
  void record({
    required DateTime sentAt,
    required DateTime answeredAt,
    required DateTime serverTime,
    DateTime? clientTime,
  }) {
    final roundTrip = answeredAt.difference(sentAt);
    if (roundTrip.isNegative || roundTrip > maxRoundTrip) return;
    if (clientTime != null && serverTime.isAtSameMomentAs(clientTime)) return;
    final midpoint = sentAt.add(roundTrip ~/ 2);
    _estimates.add(serverTime.difference(midpoint));
    if (_estimates.length > samples) _estimates.removeAt(0);
    final sorted = [..._estimates]..sort();
    final middle = sorted.length ~/ 2;
    _offset = sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }
}
