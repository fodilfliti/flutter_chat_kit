/// JSON field names of an `Attachment`.
///
/// When the URL field is missing, `url` is read as well.
class AttachmentJsonKeys {
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

  static const camelCase = AttachmentJsonKeys(
    mimeType: 'mimeType',
    localPath: 'localPath',
    remoteUrl: 'remoteUrl',
    thumbnailUrl: 'thumbnailUrl',
    duration: 'durationMs',
  );

  final String mimeType;
  final String localPath;
  final String remoteUrl;
  final String thumbnailUrl;

  /// Bytes.
  final String size;
  final String width;
  final String height;

  /// Milliseconds.
  final String duration;
  final String name;
}

/// JSON field names of a `RoomMember`.
class MemberJsonKeys {
  const MemberJsonKeys({
    this.userId = 'user_id',
    this.role = 'role',
    this.lastReadAt = 'last_read_at',
    this.lastDeliveredAt = 'last_delivered_at',
  });

  static const camelCase = MemberJsonKeys(
    userId: 'userId',
    lastReadAt: 'lastReadAt',
    lastDeliveredAt: 'lastDeliveredAt',
  );

  final String userId;
  final String role;
  final String lastReadAt;
  final String lastDeliveredAt;
}

/// JSON field names of a `ChatRoom`.
class RoomJsonKeys {
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

  static const camelCase = RoomJsonKeys(
    avatarUrl: 'avatarUrl',
    updatedAt: 'updatedAt',
    lastMessage: 'lastMessage',
    unreadCount: 'unreadCount',
    member: MemberJsonKeys.camelCase,
  );

  final String id;
  final String type;
  final String title;
  final String avatarUrl;
  final String updatedAt;
  final String members;
  final String lastMessage;
  final String unreadCount;
  final String pinned;
  final String muted;
  final String labels;
  final String metadata;

  /// Field names inside each entry of [members].
  final MemberJsonKeys member;
}

/// JSON field names of a `ChatUser`.
class UserJsonKeys {
  const UserJsonKeys({
    this.id = 'id',
    this.name = 'name',
    this.avatarUrl = 'avatar_url',
    this.metadata = 'metadata',
  });

  static const camelCase = UserJsonKeys(avatarUrl: 'avatarUrl');

  final String id;
  final String name;
  final String avatarUrl;
  final String metadata;
}
