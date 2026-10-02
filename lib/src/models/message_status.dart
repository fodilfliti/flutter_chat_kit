/// Delivery state of a message, from the current user's point of view.
///
/// `pending` and `sending` exist only locally (outbox). `delivered` and
/// `seen` are usually derived from `RoomMember` read pointers. Read from the
/// JSON `status` field with [parse].
enum MessageStatus {
  /// Waiting in the outbox, for example while offline. Shows a clock.
  pending,

  /// Being uploaded or sent right now. Shows a clock.
  sending,

  /// The server has it; the default for messages from the backend. Shows
  /// one tick.
  sent,

  /// Reached every other member's device. Shows two ticks.
  delivered,

  /// Read by every other member. Shows two ticks in the seen color.
  seen,

  /// The send failed and is no longer retried automatically. Shows an
  /// error icon; tapping it retries.
  failed;

  /// Whether the status exists only on the sending device: [pending],
  /// [sending] or [failed].
  bool get isLocal => this == pending || this == sending || this == failed;

  /// Parses [value], ignoring case; `read` means [seen] and `received`
  /// means [delivered]. Unknown or missing values mean the server has it
  /// ([sent]).
  static MessageStatus parse(Object? value) {
    if (value is! String) return MessageStatus.sent;
    final name = value.toLowerCase();
    return aliases[name] ??
        MessageStatus.values.asNameMap()[name] ??
        MessageStatus.sent;
  }

  /// Other names servers use, accepted by [parse].
  static const Map<String, MessageStatus> aliases = {
    'read': MessageStatus.seen,
    'received': MessageStatus.delivered,
  };

  /// Whether [parse] knows [value] (a name or an alias).
  static bool isKnown(String value) {
    final name = value.toLowerCase();
    return aliases.containsKey(name) ||
        MessageStatus.values.asNameMap().containsKey(name);
  }
}
