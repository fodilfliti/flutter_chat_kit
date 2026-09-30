import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

enum ChatProfileKind {
  /// The person themselves.
  personal,

  /// A business, page or team; possibly answered by several staff members.
  business;

  static ChatProfileKind parse(Object? value) => switch (value) {
    'business' => business,
    _ => personal,
  };
}

/// One identity the signed-in account can chat as: the personal profile, or
/// a business page the account owns or works for.
///
/// Its [id] becomes `ChatKit.currentUserId`: rooms, messages and read
/// pointers belong to the profile, not to the account.
@immutable
class ChatProfile {
  const ChatProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.kind = ChatProfileKind.personal,
    this.agentId,
    this.unreadCount = 0,
    this.metadata = const {},
  });

  factory ChatProfile.fromJson(Map<String, Object?> json) {
    return ChatProfile(
      id: readString(json, 'id'),
      name: readOptionalString(json['name']) ?? '',
      avatarUrl: readOptionalString(json['avatar_url']),
      kind: ChatProfileKind.parse(json['kind']),
      agentId: readOptionalString(json['agent_id']),
      unreadCount: readInt(json['unread_count']) ?? 0,
      metadata: readMap(json['metadata']),
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
  final ChatProfileKind kind;

  /// Who acts for this profile when several people share it, usually the
  /// account (or staff member) id. Pass it to `ChatKit.agentId`; it is
  /// stamped on sent messages as `Message.sentBy`. Null for personal
  /// profiles.
  final String? agentId;

  /// Unread messages, as reported by your backend. Only the active profile
  /// is connected, so the kit cannot count the others itself.
  final int unreadCount;

  /// App extras (role, verified badge, ...).
  final Map<String, Object?> metadata;

  bool get isBusiness => kind == ChatProfileKind.business;

  /// This profile as a message author, for avatars.
  ChatUser toUser() =>
      ChatUser(id: id, name: name, avatarUrl: avatarUrl, metadata: metadata);

  ChatProfile copyWith({
    String? name,
    String? avatarUrl,
    ChatProfileKind? kind,
    String? agentId,
    int? unreadCount,
    Map<String, Object?>? metadata,
  }) {
    return ChatProfile(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      kind: kind ?? this.kind,
      agentId: agentId ?? this.agentId,
      unreadCount: unreadCount ?? this.unreadCount,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return withoutNulls({
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'kind': kind.name,
      'agent_id': agentId,
      'unread_count': unreadCount == 0 ? null : unreadCount,
      'metadata': metadata.isEmpty ? null : metadata,
    });
  }

  @override
  bool operator ==(Object other) {
    return other is ChatProfile &&
        other.id == id &&
        other.name == name &&
        other.avatarUrl == avatarUrl &&
        other.kind == kind &&
        other.agentId == agentId &&
        other.unreadCount == unreadCount &&
        deepEquality.equals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatarUrl,
    kind,
    agentId,
    unreadCount,
    deepEquality.hash(metadata),
  );

  @override
  String toString() => 'ChatProfile($id, ${kind.name})';
}
