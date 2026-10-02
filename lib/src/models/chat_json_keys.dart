import 'package:flutter_chat_pro/src/models/attachment.dart';
import 'package:flutter_chat_pro/src/models/json_keys.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_status.dart';

/// JSON field names used by [MessageCodec], `ChatRoom.fromJson`,
/// `RoomMember.fromJson` and `ChatUser.fromJson`.
///
/// The defaults are snake_case (`author_id`, `created_at`, ...). Override
/// only what differs in your backend, or start from [camelCase]:
///
/// ```dart
/// const keys = ChatJsonKeys(
///   authorId: 'sender_id',
///   createdAt: 'sent_at',
///   typeAliases: {'msg': 'text', 'photo': 'image'},
///   attachmentKeys: AttachmentJsonKeys(remoteUrl: 'file_url'),
/// );
/// final message = Message.fromJson(json, keys: keys);
/// ```
///
/// Nested JSON (such as `{"sender": {"id": ...}}`) needs a small mapper
/// before decoding; see doc/adapters/your_api.md. The kit's own cache
/// always uses the defaults.
class ChatJsonKeys {
  /// Field names; each parameter defaults to the snake_case name shown in
  /// its field's doc.
  const ChatJsonKeys({
    this.type = 'type',
    this.id = 'id',
    this.localId = 'local_id',
    this.roomId = 'room_id',
    this.authorId = 'author_id',
    this.createdAt = 'created_at',
    this.editedAt = 'edited_at',
    this.deletedAt = 'deleted_at',
    this.status = 'status',
    this.replyToId = 'reply_to_id',
    this.reactions = 'reactions',
    this.metadata = 'metadata',
    this.sentBy = 'sent_by',
    this.text = 'text',
    this.caption = 'caption',
    this.attachments = 'attachments',
    this.attachment = 'attachment',
    this.duration = 'duration_ms',
    this.waveform = 'waveform',
    this.code = 'code',
    this.args = 'args',
    this.customType = 'custom_type',
    this.data = 'data',
    this.typeAliases = const {},
    this.attachmentKeys = const AttachmentJsonKeys(),
    this.roomKeys = const RoomJsonKeys(),
    this.userKeys = const UserJsonKeys(),
  });

  /// camelCase names everywhere: `roomId`, `authorId`, `createdAt`,
  /// `remoteUrl`, `mimeType`, `updatedAt`, `avatarUrl`, `userId`, ...
  static const camelCase = ChatJsonKeys(
    localId: 'localId',
    roomId: 'roomId',
    authorId: 'authorId',
    createdAt: 'createdAt',
    editedAt: 'editedAt',
    deletedAt: 'deletedAt',
    replyToId: 'replyToId',
    sentBy: 'sentBy',
    duration: 'durationMs',
    customType: 'customType',
    attachmentKeys: AttachmentJsonKeys.camelCase,
    roomKeys: RoomJsonKeys.camelCase,
    userKeys: UserJsonKeys.camelCase,
  );

  /// The message type discriminator; default `type`. Missing reads as
  /// `text`.
  final String type;

  /// `Message.id`; default `id`.
  final String id;

  /// `Message.localId`; default `local_id`.
  final String localId;

  /// `Message.roomId`; default `room_id`.
  final String roomId;

  /// `Message.authorId`; default `author_id`.
  final String authorId;

  /// `Message.createdAt`; default `created_at`.
  final String createdAt;

  /// `Message.editedAt`; default `edited_at`.
  final String editedAt;

  /// `Message.deletedAt`; default `deleted_at`.
  final String deletedAt;

  /// `Message.status`; default `status`.
  final String status;

  /// `Message.replyToId`; default `reply_to_id`.
  final String replyToId;

  /// `Message.reactions`; default `reactions`.
  final String reactions;

  /// `Message.metadata`; default `metadata`.
  final String metadata;

  /// `Message.sentBy`; default `sent_by`.
  final String sentBy;

  /// `TextMessage.text`; default `text`.
  final String text;

  /// The caption of image and video messages; default `caption`.
  final String caption;

  /// A list of attachments; default `attachments`. Image messages are
  /// encoded with it; other types read its first item when [attachment] is
  /// missing.
  final String attachments;

  /// A single attachment; default `attachment`. Video, audio and file
  /// messages are encoded with it; image messages read it when
  /// [attachments] is missing.
  final String attachment;

  /// `AudioMessage.duration` in milliseconds; default `duration_ms`.
  final String duration;

  /// `AudioMessage.waveform`; default `waveform`.
  final String waveform;

  /// `SystemMessage.code`; default `code`.
  final String code;

  /// `SystemMessage.args`; default `args`.
  final String args;

  /// `CustomMessage.customType`; default `custom_type`.
  final String customType;

  /// `CustomMessage.data`; default `data`.
  final String data;

  /// Backend type name to kit type name, applied when decoding, for example
  /// `{'msg': 'text', 'photo': 'image'}`. Encoding always writes the kit
  /// name.
  final Map<String, String> typeAliases;

  /// Field names inside attachments; see [AttachmentJsonKeys].
  final AttachmentJsonKeys attachmentKeys;

  /// Field names of rooms and their members; see [RoomJsonKeys].
  final RoomJsonKeys roomKeys;

  /// Field names of users; see [UserJsonKeys].
  final UserJsonKeys userKeys;

  /// The kit type for a backend [rawType], after [typeAliases].
  String resolveType(String rawType) => typeAliases[rawType] ?? rawType;

  /// Message fields shared by every type. For an unknown type, every other
  /// field becomes `CustomMessage.data`.
  Set<String> get baseKeys => _baseKeys;

  Set<String> get _baseKeys => {
    type,
    id,
    localId,
    roomId,
    authorId,
    createdAt,
    editedAt,
    deletedAt,
    status,
    replyToId,
    reactions,
    metadata,
    sentBy,
  };
}

typedef _Base = ({
  String id,
  String localId,
  String roomId,
  String authorId,
  DateTime createdAt,
  DateTime? editedAt,
  DateTime? deletedAt,
  MessageStatus status,
  String? replyToId,
  Map<String, Set<String>> reactions,
  Map<String, Object?> metadata,
  String? sentBy,
});

/// Encodes and decodes [Message] subtypes using [ChatJsonKeys].
///
/// Decoding is forgiving, so most backends work without a mapper:
///
/// - Dates are ISO-8601 strings, epoch milliseconds or epoch seconds; they
///   encode as ISO-8601 UTC.
/// - A missing `local_id` falls back to `id` (and vice versa); a missing
///   `room_id` falls back to the `roomId` passed to [decode].
/// - An attachment can be a bare URL string, and its mime type is guessed
///   when missing. Image messages accept one `attachment`; video, audio and
///   file messages accept an `attachments` list (the first item is used).
/// - Unknown `type` values decode to [CustomMessage] with the remaining
///   fields as `data`.
/// - Ids may be strings or numbers; durations are milliseconds; `status`
///   accepts the aliases of [MessageStatus.parse].
///
/// [Message.fromJson] and [Message.toJson] use it; create one yourself to
/// share [keys] between rooms and messages, as `ChatRoom.fromJson(codec:)`
/// does.
class MessageCodec {
  /// A codec using the field names of [keys].
  const MessageCodec({this.keys = const ChatJsonKeys()});

  /// The field names read and written.
  final ChatJsonKeys keys;

  /// Reads a message from [json].
  ///
  /// [roomId] is used when the JSON has no room id, as in the items of
  /// `GET /rooms/{id}/messages`. Throws a [FormatException] naming the
  /// field when there is no id, author, creation time or room id, or when
  /// a date cannot be read.
  Message decode(Map<String, Object?> json, {String? roomId}) {
    final type = keys.resolveType(
      readOptionalString(json[keys.type]) ?? 'text',
    );
    final b = _readBase(json, roomId);
    final k = keys;

    return switch (type) {
      'text' => TextMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        text: readOptionalString(json[k.text]) ?? '',
      ),
      'image' => ImageMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        images: _attachments(json, 'image/*'),
        caption: readOptionalString(json[k.caption]),
      ),
      'video' => VideoMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        video: _attachment(json, 'video/*'),
        caption: readOptionalString(json[k.caption]),
      ),
      'audio' => AudioMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        audio: _attachment(json, 'audio/*'),
        duration: readDuration(json[k.duration]) ?? Duration.zero,
        waveform: readDoubleList(json[k.waveform]),
      ),
      'file' => FileMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        file: _attachment(json, null),
      ),
      'system' => SystemMessage(
        id: b.id,
        localId: b.localId,
        roomId: b.roomId,
        authorId: b.authorId,
        createdAt: b.createdAt,
        editedAt: b.editedAt,
        deletedAt: b.deletedAt,
        status: b.status,
        replyToId: b.replyToId,
        reactions: b.reactions,
        metadata: b.metadata,
        sentBy: b.sentBy,
        code: readOptionalString(json[k.code]) ?? '',
        args: readMap(json[k.args]),
      ),
      'custom' => _custom(
        b,
        readOptionalString(json[k.customType]) ?? 'unknown',
        readMap(json[k.data]),
      ),
      _ => _custom(b, type, _extras(json)),
    };
  }

  /// Writes [message] as JSON with the names of [keys].
  ///
  /// Null and empty fields are left out and dates are ISO-8601 UTC. Image
  /// messages write `attachments`; video, audio and file messages write
  /// `attachment`. `status` is written by name, such as `sending`.
  Map<String, Object?> encode(Message message) {
    final k = keys;
    final a = k.attachmentKeys;
    final body = switch (message) {
      TextMessage(:final text) => {k.text: text},
      ImageMessage(:final images, :final caption) => {
        k.attachments: [for (final i in images) i.toJson(keys: a)],
        k.caption: caption,
      },
      VideoMessage(:final video, :final caption) => {
        k.attachment: video.toJson(keys: a),
        k.caption: caption,
      },
      AudioMessage(:final audio, :final duration, :final waveform) => {
        k.attachment: audio.toJson(keys: a),
        k.duration: duration.inMilliseconds,
        k.waveform: waveform.isEmpty ? null : waveform,
      },
      FileMessage(:final file) => {k.attachment: file.toJson(keys: a)},
      SystemMessage(:final code, :final args) => {
        k.code: code,
        k.args: args.isEmpty ? null : args,
      },
      CustomMessage(:final customType, :final data) => {
        k.customType: customType,
        k.data: data,
      },
    };

    return withoutNulls({
      k.type: message.type,
      k.id: message.id,
      k.localId: message.localId,
      k.roomId: message.roomId,
      k.authorId: message.authorId,
      k.createdAt: writeDate(message.createdAt),
      k.editedAt: writeDate(message.editedAt),
      k.deletedAt: writeDate(message.deletedAt),
      k.status: message.status.name,
      k.replyToId: message.replyToId,
      k.reactions: message.reactions.isEmpty
          ? null
          : writeReactions(message.reactions),
      k.metadata: message.metadata.isEmpty ? null : message.metadata,
      k.sentBy: message.sentBy,
      ...body,
    });
  }

  _Base _readBase(Map<String, Object?> json, String? fallbackRoomId) {
    final id = readOptionalString(json[keys.id]);
    final localId = readOptionalString(json[keys.localId]);
    final resolvedId = id ?? localId;
    if (resolvedId == null) {
      throw FormatException(
        'Message needs "${keys.id}" or "${keys.localId}"; '
        'set ChatJsonKeys(id: ...) if your API names it differently. '
        'Got the fields ${json.keys.toList()}.',
      );
    }
    Never missing(String field, String fix) =>
        throw FormatException('Message "$resolvedId": missing "$field". $fix');
    final roomId =
        readOptionalString(json[keys.roomId]) ??
        fallbackRoomId ??
        missing(
          keys.roomId,
          'Pass roomId: to Message.fromJson when your API leaves it out, '
          'or set ChatJsonKeys(roomId: ...).',
        );
    final authorId =
        readOptionalString(json[keys.authorId]) ??
        missing(
          keys.authorId,
          'Set ChatJsonKeys(authorId: ...) to the field holding the sender '
          'id, or copy a nested sender id into it before decoding.',
        );
    final createdAt =
        _date(json, keys.createdAt, resolvedId) ??
        missing(
          keys.createdAt,
          'Set ChatJsonKeys(createdAt: ...) to your timestamp field.',
        );
    return (
      id: resolvedId,
      localId: localId ?? resolvedId,
      roomId: roomId,
      authorId: authorId,
      createdAt: createdAt,
      editedAt: _date(json, keys.editedAt, resolvedId),
      deletedAt: _date(json, keys.deletedAt, resolvedId),
      status: MessageStatus.parse(json[keys.status]),
      replyToId: readOptionalString(json[keys.replyToId]),
      reactions: readReactions(json[keys.reactions]),
      metadata: readMap(json[keys.metadata]),
      sentBy: readOptionalString(json[keys.sentBy]),
    );
  }

  DateTime? _date(Map<String, Object?> json, String key, String id) {
    try {
      return readDate(json[key]);
    } on FormatException catch (e) {
      throw FormatException(
        'Message "$id": "$key" is not a date (${json[key]}). Use ISO-8601 '
        'with a time zone, or epoch milliseconds or seconds. ${e.message}',
      );
    }
  }

  /// The list under `attachments`, else the single `attachment`.
  List<Attachment> _attachments(Map<String, Object?> json, String? hint) {
    final raw = readList(json[keys.attachments]);
    return [
      for (final item in raw.isEmpty ? readList(json[keys.attachment]) : raw)
        if (item != null)
          Attachment.fromJson(item, keys: keys.attachmentKeys, mimeHint: hint),
    ];
  }

  /// The single `attachment`, else the first of `attachments`.
  Attachment _attachment(Map<String, Object?> json, String? hint) {
    final single = json[keys.attachment];
    final item = single ?? readList(json[keys.attachments]).firstOrNull;
    return Attachment.fromJson(item, keys: keys.attachmentKeys, mimeHint: hint);
  }

  CustomMessage _custom(_Base b, String type, Map<String, Object?> data) {
    return CustomMessage(
      id: b.id,
      localId: b.localId,
      roomId: b.roomId,
      authorId: b.authorId,
      createdAt: b.createdAt,
      editedAt: b.editedAt,
      deletedAt: b.deletedAt,
      status: b.status,
      replyToId: b.replyToId,
      reactions: b.reactions,
      metadata: b.metadata,
      sentBy: b.sentBy,
      customType: type,
      data: data,
    );
  }

  Map<String, Object?> _extras(Map<String, Object?> json) {
    final base = keys.baseKeys;
    return {
      for (final e in json.entries)
        if (!base.contains(e.key)) e.key: e.value,
    };
  }
}
