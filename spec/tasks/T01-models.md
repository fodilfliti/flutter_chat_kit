# T01 — Models and JSON codec

## Goal

Typed, immutable models for everything the kit stores, syncs and renders. They replace valizex's `Map<String, dynamic>` messages.

## Read first

- [../package.md](../package.md), [../invariants.md](../invariants.md) (Data section), [../decisions.md](../decisions.md) D4, D5, D7
- `lemsa_core_kit`: `Change<T>` (`Created`, `Updated`, `Deleted`)

## Depends on

T00.

## Deliverables

```text
lib/src/models/chat_user.dart
lib/src/models/chat_room.dart          ChatRoom, RoomType { direct, group, channel }
lib/src/models/room_member.dart        RoomMember, MemberRole { owner, admin, member }
lib/src/models/attachment.dart         Attachment, AttachmentKind
lib/src/models/message_status.dart     MessageStatus
lib/src/models/message.dart            sealed Message + 7 subtypes
lib/src/models/message_cursor.dart     MessageCursor, RoomCursor
lib/src/models/chat_page.dart          ChatPage<T>
lib/src/models/chat_event.dart         sealed ChatEvent
lib/src/models/typing.dart             TypingState
lib/src/models/presence.dart           Presence
lib/src/models/chat_json_keys.dart     ChatJsonKeys + MessageCodec
test/models/*_test.dart
```

## Public API

```dart
enum MessageStatus { pending, sending, sent, delivered, seen, failed }

@immutable
sealed class Message {
  String get id;          // server id; equals localId until confirmed
  String get localId;     // uuid v4, never changes
  String get roomId;
  String get authorId;
  DateTime get createdAt; // UTC
  DateTime? get editedAt;
  DateTime? get deletedAt;
  MessageStatus get status;
  String? get replyToId;
  Map<String, Set<String>> get reactions; // emoji -> userIds
  Map<String, Object?> get metadata;      // app extras, round-tripped untouched
  bool get isDeleted => deletedAt != null;
  MessageCursor get cursor => MessageCursor(createdAt, id);
  bool matches(String idOrLocalId);
  // Each subtype overrides copyWith with its base params plus its own fields,
  // so `Message.copyWith(status: ...)` keeps the subtype.
  Message copyWith({String? id, MessageStatus? status, DateTime? createdAt, ...});
  Map<String, Object?> toJson();
  static Message fromJson(Map<String, Object?> json, {ChatJsonKeys keys = const ChatJsonKeys()});
}

final class TextMessage extends Message { final String text; }
final class ImageMessage extends Message { final List<Attachment> images; final String? caption; }
final class VideoMessage extends Message { final Attachment video; final String? caption; }
final class AudioMessage extends Message { final Attachment audio; final Duration duration; final List<double> waveform; }
final class FileMessage extends Message { final Attachment file; }
final class SystemMessage extends Message { final String code; final Map<String, Object?> args; } // text built by ChatFormatters
final class CustomMessage extends Message { final String customType; final Map<String, Object?> data; }

@immutable
class Attachment {
  final String? localPath; final String? remoteUrl; final String? thumbnailUrl;
  final String mimeType; final int? size; final int? width; final int? height;
  final Duration? duration; final String? name;
  double? get aspectRatio;          // width / height when both known
  bool get isUploaded => remoteUrl != null;
}

@immutable
class ChatUser { final String id; final String name; final String? avatarUrl; final Map<String, Object?> metadata; }

@immutable
class RoomMember { final String userId; final MemberRole role; final DateTime? lastReadAt; final DateTime? lastDeliveredAt; }

@immutable
class ChatRoom {
  final String id; final RoomType type; final String? title; final String? avatarUrl;
  final List<RoomMember> members; final Message? lastMessage; final int unreadCount;
  final DateTime updatedAt; final bool pinned; final bool muted; final Map<String, Object?> metadata;
  String? otherUserId(String me);   // direct rooms
}

@immutable class MessageCursor { final DateTime createdAt; final String id; } // total order: createdAt, then id
@immutable class RoomCursor { final DateTime updatedAt; final String id; }
@immutable class ChatPage<T> { final List<T> items; final bool hasMore; }

sealed class ChatEvent {}
final class MessageChanged extends ChatEvent { final Change<Message> change; final String roomId; }
final class RoomChanged extends ChatEvent { final Change<ChatRoom> change; }
final class TypingChanged extends ChatEvent { final String roomId; final String userId; final bool typing; }
final class ReceiptChanged extends ChatEvent { final String roomId; final String userId; final DateTime? readAt; final DateTime? deliveredAt; }
final class PresenceChanged extends ChatEvent { final Presence presence; }

class ChatJsonKeys { const ChatJsonKeys({this.id = 'id', this.localId = 'local_id', this.roomId = 'room_id', ...}); }
```

JSON: `type` discriminator (`text`, `image`, `video`, `audio`, `file`, `system`, `custom`). Unknown `type` decodes to `CustomMessage(customType: type, data: json)` so old clients never crash on new server types. Dates are ISO-8601 UTC or epoch millis (accept both, write ISO).

## Done when

- [x] All models: `==`/`hashCode` (use `collection` equality for lists, maps, sets), `copyWith`, `toJson`/`fromJson`
- [x] Round-trip tests for every `Message` subtype, including `metadata` preservation
- [x] Unknown type → `CustomMessage` test; custom `ChatJsonKeys` test (plus `typeAliases`)
- [x] `MessageCursor` comparison test (same `createdAt`, different `id`)
- [x] Models exported from the barrel; `fvm flutter analyze` clean

## Do not

- Use `freezed` or `json_serializable` (no codegen for models; keep build_runner for Drift only)
- Put `BuildContext`, widgets, or localized text in models
- Store `isMine` on a message (derive from `authorId == currentUserId`)
