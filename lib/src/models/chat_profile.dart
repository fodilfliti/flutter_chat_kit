import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';

/// Whether a [ChatProfile] is a person or a business.
enum ChatProfileKind {
  /// The person themselves.
  personal,

  /// A business, page or team; possibly answered by several staff members.
  business;

  /// Reads `business`; anything else reads as [personal].
  static ChatProfileKind parse(Object? value) => switch (value) {
    'business' => business,
    _ => personal,
  };
}

/// One identity the signed-in account can chat as: the personal profile, or
/// a business page the account owns or works for.
///
/// Its [id] becomes `ChatKit.currentUserId`: rooms, messages and read
/// pointers belong to the profile, not to the account. Switch between
/// profiles with `ChatProfileSwitcher`; see doc/adapters/profiles.md.
@immutable
class ChatProfile {
  /// A profile; [id] and [name] are required.
  const ChatProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.kind = ChatProfileKind.personal,
    this.agentId,
    this.unreadCount = 0,
    this.metadata = const {},
  });

  /// Reads a profile with fixed snake_case names: `id` (required, else a
  /// [FormatException]), `name`, `avatar_url`, `kind` (`personal` or
  /// `business`), `agent_id`, `unread_count` and `metadata`. These names
  /// cannot be changed with `ChatJsonKeys`.
  ///
  /// ```json
  /// {"id": "shop-1", "name": "Lemsa Shop", "kind": "business",
  ///  "agent_id": "u1", "unread_count": 3}
  /// ```
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

  /// The id the profile chats as; becomes `ChatKit.currentUserId`.
  final String id;

  /// The name shown in the profile menu and to people chatting with it.
  final String name;

  /// The profile picture.
  final String? avatarUrl;

  /// Personal or business.
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

  /// Whether [kind] is [ChatProfileKind.business].
  bool get isBusiness => kind == ChatProfileKind.business;

  /// This profile as a message author, for avatars.
  ChatUser toUser() =>
      ChatUser(id: id, name: name, avatarUrl: avatarUrl, metadata: metadata);

  /// A copy with the given fields replaced; null keeps the current value.
  /// The [id] never changes.
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

  /// This profile as JSON with the names read by [ChatProfile.fromJson].
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
