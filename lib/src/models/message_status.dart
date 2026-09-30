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

  /// Parses [value]; unknown or missing values mean the server has it.
  static MessageStatus parse(Object? value) {
    if (value is! String) return MessageStatus.sent;
    return MessageStatus.values.asNameMap()[value] ?? MessageStatus.sent;
  }
}
