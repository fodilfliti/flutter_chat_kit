import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';

/// Where a message sits in a run of consecutive messages by one author.
/// `first` is the oldest (top) message of the run.
enum GroupPosition {
  single,
  first,
  middle,
  last;

  bool get isFirst => this == single || this == first;
  bool get isLast => this == single || this == last;

  /// Position of [message] given its chronological neighbours.
  ///
  /// Two messages group when they share an author, fall on the same local
  /// day, are at most [window] apart, and neither is a [SystemMessage].
  static GroupPosition of(
    Message message, {
    required Duration window,
    Message? older,
    Message? newer,
  }) {
    final joinsOlder = older != null && _groups(older, message, window);
    final joinsNewer = newer != null && _groups(message, newer, window);
    return switch ((joinsOlder, joinsNewer)) {
      (true, true) => middle,
      (false, true) => first,
      (true, false) => last,
      (false, false) => single,
    };
  }

  static bool _groups(Message older, Message newer, Duration window) {
    if (older is SystemMessage || newer is SystemMessage) return false;
    if (older.authorId != newer.authorId) return false;
    final a = older.createdAt.toLocal();
    final b = newer.createdAt.toLocal();
    if (a.year != b.year || a.month != b.month || a.day != b.day) {
      return false;
    }
    return b.difference(a).abs() <= window;
  }
}

/// Everything a message builder needs to render one row.
@immutable
class MessageContext {
  const MessageContext({
    required this.message,
    required this.currentUserId,
    required this.isMine,
    required this.groupPosition,
    required this.index,
    required this.uploadProgress,
    this.author,
    this.room,
    this.repliedTo,
    this.repliedToAuthor,
    this.seenBy = const [],
    this.displayStatus,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isHighlighted = false,
  });

  final Message message;
  final String currentUserId;

  /// Resolved author; null until the user resolver answers.
  final ChatUser? author;
  final bool isMine;
  final GroupPosition groupPosition;

  /// Position in the reversed list (0 = newest).
  final int index;

  /// Upload fraction 0..1 while an attachment uploads, otherwise null.
  /// Listen to it locally so progress never rebuilds the list.
  final ValueListenable<double?> uploadProgress;
  final ChatRoom? room;

  /// The message this one replies to, when it is loaded.
  final Message? repliedTo;

  /// Author of [repliedTo], when resolved.
  final ChatUser? repliedToAuthor;

  /// Other members whose read pointer covers this message.
  final List<RoomMember> seenBy;

  /// Status derived from the members' read pointers; see [status].
  final MessageStatus? displayStatus;
  final bool isSelected;

  /// True while at least one message is selected: taps toggle selection.
  final bool isSelectionMode;

  /// True while the jump-to-message highlight runs.
  final bool isHighlighted;

  /// The status to show: [displayStatus] when set, else the stored one.
  MessageStatus get status => displayStatus ?? message.status;

  bool get isGroupRoom => room != null && !room!.isDirect;
}
