import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// A realtime event emitted by `ChatSource.events`.
sealed class ChatEvent {
  const ChatEvent();
}

/// A message was created, updated or deleted. The sender's own confirmed
/// messages must be emitted too; the kit deduplicates by `localId`.
final class MessageChanged extends ChatEvent {
  const MessageChanged({required this.roomId, required this.change});

  final String roomId;

  /// `Deleted.id` may be the server id or the local id.
  final Change<Message> change;
}

final class RoomChanged extends ChatEvent {
  const RoomChanged(this.change);

  final Change<ChatRoom> change;
}

final class TypingChanged extends ChatEvent {
  const TypingChanged({
    required this.roomId,
    required this.userId,
    required this.typing,
  });

  final String roomId;
  final String userId;
  final bool typing;
}

/// A member's read or delivery pointer moved.
final class ReceiptChanged extends ChatEvent {
  const ReceiptChanged({
    required this.roomId,
    required this.userId,
    this.readAt,
    this.deliveredAt,
  });

  final String roomId;
  final String userId;
  final DateTime? readAt;
  final DateTime? deliveredAt;
}

final class PresenceChanged extends ChatEvent {
  const PresenceChanged(this.presence);

  final Presence presence;
}
