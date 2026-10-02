/// JSON field names of an `Attachment`.
///
/// The defaults are snake_case. When the URL field is missing, `url` is
/// read as well. Pass it as `ChatJsonKeys(attachmentKeys: ...)`, or use
/// [camelCase].
class AttachmentJsonKeys {
  /// Field names; each parameter defaults to the name shown in its field's
  /// doc.
  const AttachmentJsonKeys({
    this.mimeType = 'mime_type',
    this.localPath = 'local_path',
    this.remoteUrl = 'remote_url',
    this.thumbnailUrl = 'thumbnail_url',
    this.size = 'size',
    this.width = 'width',
    this.height = 'height',
    this.duration = 'duration_ms',
    this.name = 'name',
  });

  /// `mimeType`, `localPath`, `remoteUrl`, `thumbnailUrl` and `durationMs`;
  /// the one-word names stay the same.
  static const camelCase = AttachmentJsonKeys(
    mimeType: 'mimeType',
    localPath: 'localPath',
    remoteUrl: 'remoteUrl',
    thumbnailUrl: 'thumbnailUrl',
    duration: 'durationMs',
  );

  /// `Attachment.mimeType`; default `mime_type`.
  final String mimeType;

  /// `Attachment.localPath`; default `local_path`. Only set on the sending
  /// device.
  final String localPath;

  /// `Attachment.remoteUrl`; default `remote_url`, with `url` as a
  /// fallback.
  final String remoteUrl;

  /// `Attachment.thumbnailUrl`; default `thumbnail_url`.
  final String thumbnailUrl;

  /// `Attachment.size` in bytes; default `size`.
  final String size;

  /// `Attachment.width` in pixels; default `width`.
  final String width;

  /// `Attachment.height` in pixels; default `height`.
  final String height;

  /// `Attachment.duration` in milliseconds; default `duration_ms`.
  final String duration;

  /// `Attachment.name`; default `name`.
  final String name;
}

/// JSON field names of a `RoomMember`.
///
/// Pass it as `RoomJsonKeys(member: ...)`, or use [camelCase].
class MemberJsonKeys {
  /// Field names; each parameter defaults to the name shown in its field's
  /// doc.
  const MemberJsonKeys({
    this.userId = 'user_id',
    this.role = 'role',
    this.lastReadAt = 'last_read_at',
    this.lastDeliveredAt = 'last_delivered_at',
  });

  /// `userId`, `lastReadAt` and `lastDeliveredAt`.
  static const camelCase = MemberJsonKeys(
    userId: 'userId',
    lastReadAt: 'lastReadAt',
    lastDeliveredAt: 'lastDeliveredAt',
  );

  /// `RoomMember.userId`; default `user_id`.
  final String userId;

  /// `RoomMember.role`; default `role`.
  final String role;

  /// `RoomMember.lastReadAt`; default `last_read_at`.
  final String lastReadAt;

  /// `RoomMember.lastDeliveredAt`; default `last_delivered_at`.
  final String lastDeliveredAt;
}

/// JSON field names of a `ChatRoom`.
///
/// Pass it as `ChatJsonKeys(roomKeys: ...)`, or use [camelCase]:
///
/// ```dart
/// const keys = ChatJsonKeys(
///   roomKeys: RoomJsonKeys(
///     title: 'name',
///     updatedAt: 'last_activity',
///     member: MemberJsonKeys(lastReadAt: 'seen_at'),
///   ),
/// );
/// final room = ChatRoom.fromJson(json, keys: keys);
/// ```
class RoomJsonKeys {
  /// Field names; each parameter defaults to the name shown in its field's
  /// doc.
  const RoomJsonKeys({
    this.id = 'id',
    this.type = 'type',
    this.title = 'title',
    this.avatarUrl = 'avatar_url',
    this.updatedAt = 'updated_at',
    this.members = 'members',
    this.lastMessage = 'last_message',
    this.unreadCount = 'unread_count',
    this.pinned = 'pinned',
    this.muted = 'muted',
    this.labels = 'labels',
    this.metadata = 'metadata',
    this.member = const MemberJsonKeys(),
  });

  /// `avatarUrl`, `updatedAt`, `lastMessage`, `unreadCount` and
  /// [MemberJsonKeys.camelCase].
  static const camelCase = RoomJsonKeys(
    avatarUrl: 'avatarUrl',
    updatedAt: 'updatedAt',
    lastMessage: 'lastMessage',
    unreadCount: 'unreadCount',
    member: MemberJsonKeys.camelCase,
  );

  /// `ChatRoom.id`; default `id`.
  final String id;

  /// `ChatRoom.type`; default `type`.
  final String type;

  /// `ChatRoom.title`; default `title`.
  final String title;

  /// `ChatRoom.avatarUrl`; default `avatar_url`.
  final String avatarUrl;

  /// `ChatRoom.updatedAt`; default `updated_at`.
  final String updatedAt;

  /// `ChatRoom.members`; default `members`.
  final String members;

  /// `ChatRoom.lastMessage`; default `last_message`.
  final String lastMessage;

  /// `ChatRoom.unreadCount`; default `unread_count`.
  final String unreadCount;

  /// `ChatRoom.pinned`; default `pinned`.
  final String pinned;

  /// `ChatRoom.muted`; default `muted`.
  final String muted;

  /// `ChatRoom.labels`; default `labels`.
  final String labels;

  /// `ChatRoom.metadata`; default `metadata`.
  final String metadata;

  /// Field names inside each entry of [members].
  final MemberJsonKeys member;
}

/// JSON field names of a `ChatUser`.
///
/// Pass it as `ChatJsonKeys(userKeys: ...)` or straight to
/// `ChatUser.fromJson(keys:)`, or use [camelCase].
class UserJsonKeys {
  /// Field names; each parameter defaults to the name shown in its field's
  /// doc.
  const UserJsonKeys({
    this.id = 'id',
    this.name = 'name',
    this.avatarUrl = 'avatar_url',
    this.metadata = 'metadata',
  });

  /// `avatarUrl`; the other names stay the same.
  static const camelCase = UserJsonKeys(avatarUrl: 'avatarUrl');

  /// `ChatUser.id`; default `id`.
  final String id;

  /// `ChatUser.name`; default `name`.
  final String name;

  /// `ChatUser.avatarUrl`; default `avatar_url`.
  final String avatarUrl;

  /// `ChatUser.metadata`; default `metadata`.
  final String metadata;
}
