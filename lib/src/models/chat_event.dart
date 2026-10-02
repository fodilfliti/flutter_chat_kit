import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/presence.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// A realtime event emitted by `ChatSource.events`.
///
/// Map each push from your backend (snapshot, WebSocket frame, row change)
/// to one of the subtypes:
///
/// ```dart
/// Stream<ChatEvent> events({String? roomId}) => socket.frames
///     .where((f) => f['type'] == 'message.created')
///     .map((f) => MessageChanged(
///           roomId: f['room_id'] as String,
///           change: Created(
///             Message.fromJson(f['message'] as Map<String, Object?>),
///           ),
///         ));
/// ```
///
/// See doc/adapters/rest_websocket.md for a full mapping.
sealed class ChatEvent {
  /// Base constructor of every event.
  const ChatEvent();
}

/// A message was created, updated or deleted. The sender's own confirmed
/// messages must be emitted too; the kit deduplicates by `localId`.
///
/// Use `Created` for a new message, `Updated` for an edit, a reaction, a
/// soft delete or a status change, and `Deleted` with the message id to
/// remove it from the list. `Created`, `Updated` and `Deleted` come from
/// `lemsa_core_kit`.
final class MessageChanged extends ChatEvent {
  /// A change to one message of [roomId].
  const MessageChanged({required this.roomId, required this.change});

  /// The room of the message.
  final String roomId;

  /// The change. `Deleted.id` may be the server id or the local id.
  final Change<Message> change;
}

/// A room was created, updated (new last message, title, unread count,
/// members) or removed. Emit it from the inbox stream (`roomId` null); the
/// inbox re-sorts and updates the row. Use `Created` or `Updated` with the
/// whole room, or `Deleted` with its id.
final class RoomChanged extends ChatEvent {
  /// A change to one room.
  const RoomChanged(this.change);

  /// The change; `Deleted.id` is the room id.
  final Change<ChatRoom> change;
}

/// A member started or stopped typing in a room. Shows "... is typing" in
/// the app bar and inbox row. The kit clears it by itself after
/// `ChatConfig.typingTimeout` without a new event, in case the stop event
/// is lost, and when that member's message arrives.
final class TypingChanged extends ChatEvent {
  /// [userId] is typing in [roomId] when [typing] is true.
  const TypingChanged({
    required this.roomId,
    required this.userId,
    required this.typing,
  });

  /// The room.
  final String roomId;

  /// Who is typing.
  final String userId;

  /// True when typing started, false when it stopped.
  final bool typing;
}

/// A member's read or delivery pointer moved, which updates the ticks on
/// the current user's messages.
final class ReceiptChanged extends ChatEvent {
  /// A pointer of [userId] in [roomId] moved; pass the pointers that
  /// changed.
  const ReceiptChanged({
    required this.roomId,
    required this.userId,
    this.readAt,
    this.deliveredAt,
  });

  /// The room.
  final String roomId;

  /// The member whose pointer moved.
  final String userId;

  /// The new `RoomMember.lastReadAt`, or null to keep the current one.
  /// Pointers only move forward; an older time is ignored.
  final DateTime? readAt;

  /// The new `RoomMember.lastDeliveredAt`, or null to keep the current one.
  /// Pointers only move forward; an older time is ignored.
  final DateTime? deliveredAt;
}

/// A user came online or went offline. Shows the online dot and "online" /
/// "last seen" in direct rooms. Emit it from the inbox stream.
final class PresenceChanged extends ChatEvent {
  /// The new [presence] of one user.
  const PresenceChanged(this.presence);

  /// The user's online state.
  final Presence presence;
}

/// Names or avatars changed, or arrived with a realtime payload. The kit
/// stores them and updates every open screen. Emit it from the inbox or a
/// room stream.
final class UsersChanged extends ChatEvent {
  /// New or changed [users].
  const UsersChanged(this.users);

  /// The users to store; they replace stored users with the same id.
  final List<ChatUser> users;
}
