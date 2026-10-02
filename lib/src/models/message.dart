import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/chat_json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';

/// A chat message. Switch over the sealed subtypes to render it.
///
/// The subtypes are [TextMessage], [ImageMessage], [VideoMessage],
/// [AudioMessage], [FileMessage], [SystemMessage] and [CustomMessage]. The
/// JSON `type` field picks the subtype; unknown types become a
/// [CustomMessage], so old app versions never crash on new types.
///
/// [localId] is created on the client (uuid v4) and never changes: it is the
/// widget key and the idempotency key for `ChatSource.send`. [id] equals
/// [localId] until the server confirms a different id.
///
/// Read backend JSON with [Message.fromJson]; field names are set by
/// [ChatJsonKeys]. The smallest valid message:
///
/// ```json
/// {"id": "m1", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:00:00Z", "text": "Hi"}
/// ```
///
/// See doc/backend_json.md for every field.
@immutable
sealed class Message {
  /// Base constructor of every subtype; build a subtype such as
  /// [TextMessage] instead.
  const Message({
    required this.id,
    required this.localId,
    required this.roomId,
    required this.authorId,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.reactions = const {},
    this.metadata = const {},
    this.sentBy,
  });

  /// Reads a message of any type from backend JSON.
  ///
  /// Required: `id` (or `local_id`), `author_id`, `created_at`, and
  /// `room_id` unless [roomId] is given. A missing required field throws a
  /// [FormatException] that names the field and the fix. Everything else
  /// has a default. Ids may be strings or numbers; dates may be ISO-8601,
  /// epoch milliseconds or epoch seconds. See [MessageCodec] for the full
  /// rules and `ChatJsonCheck.message` to test real responses.
  ///
  /// [keys] renames fields (for example [ChatJsonKeys.camelCase]). [roomId]
  /// is used when the JSON has no room id, as in the items of
  /// `GET /rooms/{id}/messages`:
  ///
  /// ```dart
  /// final messages = [
  ///   for (final item in body['items'] as List)
  ///     Message.fromJson(item as Map<String, Object?>,
  ///         keys: const ChatJsonKeys(authorId: 'sender_id'),
  ///         roomId: roomId),
  /// ];
  /// ```
  factory Message.fromJson(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
    String? roomId,
  }) {
    return MessageCodec(keys: keys).decode(json, roomId: roomId);
  }

  /// The server id (JSON `id`), or [localId] until the server confirms the
  /// send. Accepts a string or a number.
  final String id;

  /// The client id (JSON `local_id`), created when the message is composed
  /// and never changed.
  ///
  /// The kit uses it as the widget key and to match the server echo with
  /// the pending bubble, so `ChatSource.send` must store it and send it
  /// back. When missing in JSON it falls back to [id].
  final String localId;

  /// The room this message belongs to (JSON `room_id`). When the JSON has
  /// none, pass `roomId:` to [Message.fromJson].
  final String roomId;

  /// The user, or profile, who wrote the message (JSON `author_id`).
  ///
  /// Required. Messages where it equals `ChatKit.currentUserId` are drawn
  /// on the "mine" side; others show this user's name and avatar in groups.
  final String authorId;

  /// When the message was sent (JSON `created_at`), in UTC. Required.
  ///
  /// Orders the room (then [id] breaks ties) and is compared with
  /// `RoomMember.lastReadAt` for read ticks. A pending message uses the
  /// phone time, replaced by the server time when the send is confirmed.
  final DateTime createdAt;

  /// When the text was last edited (JSON `edited_at`). Shows an "edited"
  /// label next to the time.
  final DateTime? editedAt;

  /// When the message was deleted (JSON `deleted_at`). A deleted message
  /// keeps its place in the list and shows "This message was deleted".
  final DateTime? deletedAt;

  /// Delivery state (JSON `status`), which drives the ticks on my messages.
  ///
  /// Missing or unknown values read as [MessageStatus.sent]; see
  /// [MessageStatus.parse] for the accepted names.
  final MessageStatus status;

  /// The message this one replies to (JSON `reply_to_id`). The bubble then
  /// shows a quote of that message; tapping it jumps to it.
  final String? replyToId;

  /// Emoji to the ids of users who reacted with it (JSON `reactions`), for
  /// example `{"👍": ["u1", "u2"]}`. Shown as chips under the bubble.
  final Map<String, Set<String>> reactions;

  /// App extras (JSON `metadata`), kept and sent back untouched. The kit
  /// never reads it.
  final Map<String, Object?> metadata;

  /// The staff member who sent this message on behalf of [authorId], when a
  /// business profile is shared by several people (`ChatKit.agentId`).
  /// JSON `sent_by`. The bubble shows this person's name to the other
  /// staff. Null for personal profiles.
  final String? sentBy;

  /// JSON discriminator: `text`, `image`, `video`, `audio`, `file`,
  /// `system` or `custom`.
  String get type;

  /// Whether the message was deleted ([deletedAt] is set).
  bool get isDeleted => deletedAt != null;

  /// Whether the message was edited ([editedAt] is set).
  bool get isEdited => editedAt != null;

  /// This message's position in the room history, for paging with
  /// `ChatSource.fetchMessages`.
  MessageCursor get cursor => MessageCursor(createdAt, id);

  /// Whether [idOrLocalId] identifies this message.
  bool matches(String idOrLocalId) =>
      id == idOrLocalId || localId == idOrLocalId;

  /// A copy with the given fields replaced. A null argument keeps the
  /// current value, so a field cannot be cleared this way.
  Message copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
  });

  /// This message as JSON with the field names of [keys]. Null and empty
  /// fields are left out; dates are written as ISO-8601 UTC. See
  /// [MessageCodec.encode].
  Map<String, Object?> toJson({ChatJsonKeys keys = const ChatJsonKeys()}) {
    return MessageCodec(keys: keys).encode(this);
  }

  /// Compares the fields shared by every subtype; used by `==` in subtypes.
  @protected
  bool baseEquals(Message other) {
    return other.id == id &&
        other.localId == localId &&
        other.roomId == roomId &&
        other.authorId == authorId &&
        other.createdAt == createdAt &&
        other.editedAt == editedAt &&
        other.deletedAt == deletedAt &&
        other.status == status &&
        other.replyToId == replyToId &&
        deepEquality.equals(other.reactions, reactions) &&
        deepEquality.equals(other.metadata, metadata) &&
        other.sentBy == sentBy;
  }

  /// Hash of the fields shared by every subtype; used by `hashCode` in
  /// subtypes.
  @protected
  int get baseHashCode => Object.hash(
    id,
    localId,
    roomId,
    authorId,
    createdAt,
    editedAt,
    deletedAt,
    status,
    replyToId,
    deepEquality.hash(reactions),
    deepEquality.hash(metadata),
    sentBy,
  );

  @override
  String toString() => 'Message.$type($id, room: $roomId, ${status.name})';
}

/// A plain text message. Links in [text] are tappable.
///
/// JSON `type` is `text`, which is also the default when `type` is missing:
///
/// ```json
/// {"type": "text", "id": "m1", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:00:00Z", "text": "See you at 5"}
/// ```
final class TextMessage extends Message {
  /// A text message; [text] is required.
  const TextMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.text,
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// The message body (JSON `text`). Missing reads as an empty string.
  final String text;

  @override
  String get type => 'text';

  @override
  TextMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    String? text,
  }) {
    return TextMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TextMessage && baseEquals(other) && other.text == text;
  }

  @override
  int get hashCode => Object.hash(baseHashCode, text);
}

/// One or more photos, with an optional caption. Several images show as a
/// grid in one bubble.
///
/// JSON `type` is `image`. Images are read from `attachments` (a list) or a
/// single `attachment`; each item can be an object or a bare URL:
///
/// ```json
/// {"type": "image", "id": "m2", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:01:00Z",
///  "attachments": ["https://cdn.example.com/a.jpg"], "caption": "Lake"}
/// ```
///
/// Send `width` and `height` in each attachment so the bubble keeps its
/// size while the image loads.
final class ImageMessage extends Message {
  /// An image message; [images] is required.
  const ImageMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.images,
    this.caption,
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// The photos, in display order (JSON `attachments`, else `attachment`).
  /// Encoded as `attachments`.
  final List<Attachment> images;

  /// Text shown under the images (JSON `caption`).
  final String? caption;

  @override
  String get type => 'image';

  @override
  ImageMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    List<Attachment>? images,
    String? caption,
  }) {
    return ImageMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      images: images ?? this.images,
      caption: caption ?? this.caption,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageMessage &&
        baseEquals(other) &&
        deepEquality.equals(other.images, images) &&
        other.caption == caption;
  }

  @override
  int get hashCode =>
      Object.hash(baseHashCode, deepEquality.hash(images), caption);
}

/// One video with an optional caption, shown as a poster with a play button
/// and played in the media viewer.
///
/// JSON `type` is `video`. The video is read from `attachment`, else the
/// first item of `attachments`:
///
/// ```json
/// {"type": "video", "id": "m3", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:02:00Z",
///  "attachment": {"remote_url": "https://cdn.example.com/v.mp4",
///    "thumbnail_url": "https://cdn.example.com/v.jpg",
///    "width": 1280, "height": 720, "duration_ms": 8000}}
/// ```
final class VideoMessage extends Message {
  /// A video message; [video] is required.
  const VideoMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.video,
    this.caption,
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// The video file. Its `thumbnailUrl` is shown before playback and its
  /// `width` / `height` size the bubble.
  final Attachment video;

  /// Text shown under the video (JSON `caption`).
  final String? caption;

  @override
  String get type => 'video';

  @override
  VideoMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    Attachment? video,
    String? caption,
  }) {
    return VideoMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      video: video ?? this.video,
      caption: caption ?? this.caption,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VideoMessage &&
        baseEquals(other) &&
        other.video == video &&
        other.caption == caption;
  }

  @override
  int get hashCode => Object.hash(baseHashCode, video, caption);
}

/// A voice message, shown with a play button, a waveform and its length.
///
/// JSON `type` is `audio`. The file is read from `attachment`, else the
/// first item of `attachments`:
///
/// ```json
/// {"type": "audio", "id": "m4", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:03:00Z",
///  "attachment": "https://cdn.example.com/voice.m4a",
///  "duration_ms": 4200, "waveform": [0.1, 0.6, 0.3]}
/// ```
final class AudioMessage extends Message {
  /// A voice message; [audio] and [duration] are required.
  const AudioMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.audio,
    required this.duration,
    this.waveform = const [],
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// The audio file.
  final Attachment audio;

  /// Length shown next to the waveform (JSON `duration_ms`, milliseconds).
  /// Missing reads as zero, which shows 0:00 until playback starts.
  final Duration duration;

  /// Normalized amplitudes (0..1) used to draw the waveform bars (JSON
  /// `waveform`). Empty draws flat bars.
  final List<double> waveform;

  @override
  String get type => 'audio';

  @override
  AudioMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    Attachment? audio,
    Duration? duration,
    List<double>? waveform,
  }) {
    return AudioMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      audio: audio ?? this.audio,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioMessage &&
        baseEquals(other) &&
        other.audio == audio &&
        other.duration == duration &&
        deepEquality.equals(other.waveform, waveform);
  }

  @override
  int get hashCode =>
      Object.hash(baseHashCode, audio, duration, deepEquality.hash(waveform));
}

/// A document of any kind, shown with an icon, its name and size; tapping
/// it opens or saves the file.
///
/// JSON `type` is `file`. The file is read from `attachment`, else the
/// first item of `attachments`:
///
/// ```json
/// {"type": "file", "id": "m5", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:04:00Z",
///  "attachment": {"remote_url": "https://cdn.example.com/menu.pdf",
///    "name": "menu.pdf", "size": 48213}}
/// ```
final class FileMessage extends Message {
  /// A file message; [file] is required.
  const FileMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.file,
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// The file. Its `name` and `size` are shown in the bubble.
  final Attachment file;

  @override
  String get type => 'file';

  @override
  FileMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    Attachment? file,
  }) {
    return FileMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      file: file ?? this.file,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FileMessage && baseEquals(other) && other.file == file;
  }

  @override
  int get hashCode => Object.hash(baseHashCode, file);
}

/// A room event ("Ana joined", "Title changed"), shown centered without a
/// bubble.
///
/// The text is produced by `ChatStrings.system(code, args)` so apps control
/// the wording and the language. JSON `type` is `system`:
///
/// ```json
/// {"type": "system", "id": "m6", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:05:00Z",
///  "code": "member_joined", "args": {"name": "Ana"}}
/// ```
final class SystemMessage extends Message {
  /// A system message; [code] is required.
  const SystemMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.code,
    this.args = const {},
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// What happened, as an app-defined code such as `member_joined` (JSON
  /// `code`). Passed to `ChatStrings.system`.
  final String code;

  /// Values for the text, such as a name (JSON `args`). Passed to
  /// `ChatStrings.system`.
  final Map<String, Object?> args;

  @override
  String get type => 'system';

  @override
  SystemMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    String? code,
    Map<String, Object?>? args,
  }) {
    return SystemMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      code: code ?? this.code,
      args: args ?? this.args,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SystemMessage &&
        baseEquals(other) &&
        other.code == code &&
        deepEquality.equals(other.args, args);
  }

  @override
  int get hashCode => Object.hash(baseHashCode, code, deepEquality.hash(args));
}

/// A message type the kit does not know, such as an offer card.
///
/// Rendered by `ChatBuilders.customBuilders[customType]`; without a builder
/// it shows as "unsupported message". Its inbox preview comes from
/// `ChatStrings.customPreview`. Send one with
/// `ChatRoomController.sendCustom`.
///
/// Two JSON shapes decode to it. The explicit one:
///
/// ```json
/// {"type": "custom", "custom_type": "offer", "data": {"price": 45},
///  "id": "m7", "room_id": "r1", "author_id": "u1",
///  "created_at": "2026-01-02T10:06:00Z"}
/// ```
///
/// Or any unknown `type`, such as `{"type": "offer", "price": 45, ...}`:
/// [customType] is then `offer` and every non-message field goes into
/// [data]. So old app versions never crash on new types.
final class CustomMessage extends Message {
  /// A custom message; [customType] is required.
  const CustomMessage({
    required super.id,
    required super.localId,
    required super.roomId,
    required super.authorId,
    required super.createdAt,
    required this.customType,
    this.data = const {},
    super.editedAt,
    super.deletedAt,
    super.status,
    super.replyToId,
    super.reactions,
    super.metadata,
    super.sentBy,
  });

  /// Which builder draws it, the key of `ChatBuilders.customBuilders`
  /// (JSON `custom_type`, or the unknown `type` value). Reads `unknown`
  /// when a `custom` message has no `custom_type`.
  final String customType;

  /// The payload the builder reads (JSON `data`, or the extra fields of an
  /// unknown type). Kept and sent back untouched.
  final Map<String, Object?> data;

  @override
  String get type => 'custom';

  @override
  CustomMessage copyWith({
    String? id,
    String? localId,
    String? roomId,
    String? authorId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
    Map<String, Set<String>>? reactions,
    Map<String, Object?>? metadata,
    String? sentBy,
    String? customType,
    Map<String, Object?>? data,
  }) {
    return CustomMessage(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      sentBy: sentBy ?? this.sentBy,
      customType: customType ?? this.customType,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CustomMessage &&
        baseEquals(other) &&
        other.customType == customType &&
        deepEquality.equals(other.data, data);
  }

  @override
  int get hashCode =>
      Object.hash(baseHashCode, customType, deepEquality.hash(data));
}
