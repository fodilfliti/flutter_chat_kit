import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/chat_json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';

/// A chat message. Switch over the sealed subtypes to render it.
///
/// [localId] is created on the client (uuid v4) and never changes: it is the
/// widget key and the idempotency key for `ChatSource.send`. [id] equals
/// [localId] until the server confirms a different id.
@immutable
sealed class Message {
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
  });

  factory Message.fromJson(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
  }) {
    return MessageCodec(keys: keys).decode(json);
  }

  final String id;
  final String localId;
  final String roomId;
  final String authorId;

  /// UTC. Replaced by the server time when the send is confirmed.
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final MessageStatus status;
  final String? replyToId;

  /// Emoji to the ids of users who reacted with it.
  final Map<String, Set<String>> reactions;

  /// App extras, round-tripped untouched.
  final Map<String, Object?> metadata;

  /// JSON discriminator: `text`, `image`, `video`, `audio`, `file`,
  /// `system` or `custom`.
  String get type;

  bool get isDeleted => deletedAt != null;

  bool get isEdited => editedAt != null;

  MessageCursor get cursor => MessageCursor(createdAt, id);

  /// Whether [idOrLocalId] identifies this message.
  bool matches(String idOrLocalId) =>
      id == idOrLocalId || localId == idOrLocalId;

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
  });

  Map<String, Object?> toJson({ChatJsonKeys keys = const ChatJsonKeys()}) {
    return MessageCodec(keys: keys).encode(this);
  }

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
        deepEquality.equals(other.metadata, metadata);
  }

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
  );

  @override
  String toString() => 'Message.$type($id, room: $roomId, ${status.name})';
}

final class TextMessage extends Message {
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
  });

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

final class ImageMessage extends Message {
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
  });

  final List<Attachment> images;
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

final class VideoMessage extends Message {
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
  });

  final Attachment video;
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

final class AudioMessage extends Message {
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
  });

  final Attachment audio;
  final Duration duration;

  /// Normalized amplitudes (0..1) used to draw the waveform bars.
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

final class FileMessage extends Message {
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
  });

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

/// A room event ("Ana joined", "Title changed"). The text is produced by
/// `ChatStrings.system(code, args)` so apps control the wording.
final class SystemMessage extends Message {
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
  });

  final String code;
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
/// Rendered by `ChatBuilders.customBuilders[customType]`. Unknown JSON types
/// also decode to this class, so old clients never crash on new types.
final class CustomMessage extends Message {
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
  });

  final String customType;
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
