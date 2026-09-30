import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';

/// JSON field names used by [MessageCodec].
///
/// Override only what differs in your backend, for example
/// `ChatJsonKeys(authorId: 'sender_id', typeAliases: {'msg': 'text'})`.
class ChatJsonKeys {
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
  });

  final String type;
  final String id;
  final String localId;
  final String roomId;
  final String authorId;
  final String createdAt;
  final String editedAt;
  final String deletedAt;
  final String status;
  final String replyToId;
  final String reactions;
  final String metadata;
  final String text;
  final String caption;
  final String attachments;
  final String attachment;
  final String duration;
  final String waveform;
  final String code;
  final String args;
  final String customType;
  final String data;

  /// Backend type name to kit type name, applied when decoding.
  final Map<String, String> typeAliases;

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
});

/// Encodes and decodes [Message] subtypes using [ChatJsonKeys].
///
/// Dates decode from ISO-8601 strings or epoch milliseconds and encode as
/// ISO-8601 UTC. A missing `local_id` falls back to `id` (and vice versa).
/// Unknown `type` values decode to [CustomMessage] with the remaining fields
/// as `data`.
class MessageCodec {
  const MessageCodec({this.keys = const ChatJsonKeys()});

  final ChatJsonKeys keys;

  Message decode(Map<String, Object?> json) {
    final rawType = readOptionalString(json[keys.type]) ?? 'text';
    final type = keys.typeAliases[rawType] ?? rawType;
    final b = _readBase(json);
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
        images: [
          for (final a in readMapList(json[k.attachments]))
            Attachment.fromJson(a),
        ],
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
        video: Attachment.fromJson(readMap(json[k.attachment])),
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
        audio: Attachment.fromJson(readMap(json[k.attachment])),
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
        file: Attachment.fromJson(readMap(json[k.attachment])),
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

  Map<String, Object?> encode(Message message) {
    final k = keys;
    final body = switch (message) {
      TextMessage(:final text) => {k.text: text},
      ImageMessage(:final images, :final caption) => {
        k.attachments: [for (final a in images) a.toJson()],
        k.caption: caption,
      },
      VideoMessage(:final video, :final caption) => {
        k.attachment: video.toJson(),
        k.caption: caption,
      },
      AudioMessage(:final audio, :final duration, :final waveform) => {
        k.attachment: audio.toJson(),
        k.duration: duration.inMilliseconds,
        k.waveform: waveform.isEmpty ? null : waveform,
      },
      FileMessage(:final file) => {k.attachment: file.toJson()},
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
      ...body,
    });
  }

  _Base _readBase(Map<String, Object?> json) {
    final id = readOptionalString(json[keys.id]);
    final localId = readOptionalString(json[keys.localId]);
    final resolvedId = id ?? localId;
    if (resolvedId == null) {
      throw FormatException('Message needs "${keys.id}" or "${keys.localId}"');
    }
    return (
      id: resolvedId,
      localId: localId ?? resolvedId,
      roomId: readString(json, keys.roomId),
      authorId: readString(json, keys.authorId),
      createdAt: readRequiredDate(json, keys.createdAt),
      editedAt: readDate(json[keys.editedAt]),
      deletedAt: readDate(json[keys.deletedAt]),
      status: MessageStatus.parse(json[keys.status]),
      replyToId: readOptionalString(json[keys.replyToId]),
      reactions: readReactions(json[keys.reactions]),
      metadata: readMap(json[keys.metadata]),
    );
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
      customType: type,
      data: data,
    );
  }

  Map<String, Object?> _extras(Map<String, Object?> json) {
    final base = keys._baseKeys;
    return {
      for (final e in json.entries)
        if (!base.contains(e.key)) e.key: e.value,
    };
  }
}
