/// Delivery state of a message, from the current user's point of view.
///
/// `pending` and `sending` exist only locally (outbox). `delivered` and
/// `seen` are usually derived from `RoomMember` read pointers.
enum MessageStatus {
  pending,
  sending,
  sent,
  delivered,
  seen,
  failed;

  bool get isLocal => this == pending || this == sending || this == failed;

  /// Parses [value], ignoring case; `read` means [seen] and `received`
  /// means [delivered]. Unknown or missing values mean the server has it.
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
