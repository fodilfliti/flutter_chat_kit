import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';

/// Which slice of a room's cached history the message list shows.
///
/// The repository only hands out windows whose messages are contiguous, so
/// the list never shows a hole in the history.
@immutable
sealed class RoomWindow {
  const RoomWindow();

  /// Older messages exist beyond the window (cached or remote).
  bool get hasMoreOlder;

  /// Newer messages exist beyond the window.
  bool get hasMoreNewer;
}

/// Everything from [from] up to the newest message. New messages appear
/// without pushing older ones out.
final class LatestWindow extends RoomWindow {
  const LatestWindow({this.from, this.hasMoreOlder = true});

  /// Oldest message shown (inclusive). Null shows the whole room, which
  /// only happens while the room is empty.
  final MessageCursor? from;

  @override
  final bool hasMoreOlder;

  @override
  bool get hasMoreNewer => false;

  @override
  bool operator ==(Object other) =>
      other is LatestWindow &&
      other.from == from &&
      other.hasMoreOlder == hasMoreOlder;

  @override
  int get hashCode => Object.hash(from, hasMoreOlder);

  @override
  String toString() => 'LatestWindow(from: $from, older: $hasMoreOlder)';
}

/// A slice of old history reached by a jump, not connected to the newest
/// messages yet. Loading newer eventually turns it into a [LatestWindow].
final class DetachedWindow extends RoomWindow {
  const DetachedWindow({
    required this.oldest,
    required this.newest,
    this.hasMoreOlder = true,
    this.hasMoreNewer = true,
  });

  /// Inclusive bounds.
  final MessageCursor oldest;
  final MessageCursor newest;

  @override
  final bool hasMoreOlder;

  @override
  final bool hasMoreNewer;

  @override
  bool operator ==(Object other) =>
      other is DetachedWindow &&
      other.oldest == oldest &&
      other.newest == newest &&
      other.hasMoreOlder == hasMoreOlder &&
      other.hasMoreNewer == hasMoreNewer;

  @override
  int get hashCode => Object.hash(oldest, newest, hasMoreOlder, hasMoreNewer);

  @override
  String toString() => 'DetachedWindow($oldest .. $newest)';
}
