import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_status.dart';
import 'package:flutter_chat_pro/src/models/room_member.dart';

/// Where a message sits in a run of consecutive messages by one author.
/// `first` is the oldest (top) message of the run.
enum GroupPosition {
  /// Not grouped with either neighbour.
  single,

  /// The oldest message of a run; the author name shows above it.
  first,

  /// Inside a run, between two messages of the same author.
  middle,

  /// The newest message of a run; the avatar shows next to it.
  last;

  /// Whether the message starts a run ([single] or [first]).
  bool get isFirst => this == single || this == first;

  /// Whether the message ends a run ([single] or [last]).
  bool get isLast => this == single || this == last;

  /// Position of [message] given its chronological neighbours.
  ///
  /// Two messages group when they share an author (and staff sender), fall
  /// on the same local day, are at most [window] apart, and neither is a
  /// [SystemMessage].
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
    if (older.sentBy != newer.sentBy) return false;
    final a = older.createdAt.toLocal();
    final b = newer.createdAt.toLocal();
    if (a.year != b.year || a.month != b.month || a.day != b.day) {
      return false;
    }
    return b.difference(a).abs() <= window;
  }
}

/// Everything a message builder needs to render one row.
///
/// Passed to every `ChatBuilders` message hook and to the tap callbacks of
/// `ChatRoomView`.
///
/// ```dart
/// statusBuilder: (context, m, ticks) => m.status == MessageStatus.seen
///     ? Text('Seen by ${m.seenBy.length}')
///     : ticks,
/// ```
@immutable
class MessageContext {
  /// Built by the message list for each row.
  const MessageContext({
    required this.message,
    required this.currentUserId,
    required this.isMine,
    required this.groupPosition,
    required this.index,
    required this.uploadProgress,
    this.author,
    this.agentId,
    this.sender,
    this.room,
    this.repliedTo,
    this.repliedToAuthor,
    this.seenBy = const [],
    this.displayStatus,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isHighlighted = false,
  });

  /// The message of this row.
  final Message message;

  /// `ChatKit.currentUserId`.
  final String currentUserId;

  /// Resolved author; null until the user resolver answers.
  final ChatUser? author;

  /// `ChatKit.agentId`: the staff member using a shared business profile.
  final String? agentId;

  /// The staff member in `Message.sentBy`, once resolved.
  final ChatUser? sender;

  /// Sent as the current profile. For a shared business profile this
  /// includes messages written by colleagues; see [isSentByMe].
  final bool isMine;

  /// Where the message sits in a run by the same author; drives spacing,
  /// bubble corners, the avatar and the name.
  final GroupPosition groupPosition;

  /// Position in the reversed list (0 = newest).
  final int index;

  /// Upload fraction 0..1 while an attachment uploads, otherwise null.
  /// Listen to it locally so progress never rebuilds the list.
  final ValueListenable<double?> uploadProgress;

  /// The room, once cached.
  final ChatRoom? room;

  /// The message this one replies to, when it is loaded.
  final Message? repliedTo;

  /// Author of [repliedTo], when resolved.
  final ChatUser? repliedToAuthor;

  /// Other members whose read pointer covers this message.
  final List<RoomMember> seenBy;

  /// Status derived from the members' read pointers; see [status].
  final MessageStatus? displayStatus;

  /// Whether this message is selected (the row is tinted).
  final bool isSelected;

  /// True while at least one message is selected: taps toggle selection.
  final bool isSelectionMode;

  /// True while the jump-to-message highlight runs.
  final bool isHighlighted;

  /// The status to show: [displayStatus] when set, else the stored one.
  MessageStatus get status => displayStatus ?? message.status;

  /// Whether the room is known and not a direct chat.
  bool get isGroupRoom => room != null && !room!.isDirect;

  /// [isMine] and written by this person, not by a colleague sharing the
  /// profile. Only such messages can be edited.
  bool get isSentByMe {
    final sentBy = message.sentBy;
    return isMine && (sentBy == null || sentBy == agentId);
  }

  /// [isMine] but written by another staff member of the business profile.
  bool get isSentByColleague => isMine && !isSentByMe;
}
