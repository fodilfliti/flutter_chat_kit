import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// A person who can author messages: the name and avatar shown on bubbles,
/// inbox rows and app bars.
///
/// The kit gets users from `ChatPage.users`, the `UsersChanged` event,
/// `ChatKit.updateUsers` or a `ChatUserResolver`, and caches them. Field
/// names come from [UserJsonKeys]:
///
/// ```json
/// {"id": "u2", "name": "Lina Mansouri",
///  "avatar_url": "https://cdn.example.com/u2.jpg"}
/// ```
@immutable
class ChatUser {
  /// A user; [id] and [name] are required.
  const ChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.metadata = const {},
  });

  /// Reads a user from backend JSON.
  ///
  /// `id` (a string or a number) is required, else it throws a
  /// [FormatException]. A missing `name` reads as an empty string. Check
  /// real responses with `ChatJsonCheck.user`.
  factory ChatUser.fromJson(
    Map<String, Object?> json, {
    UserJsonKeys keys = const UserJsonKeys(),
  }) {
    final id = readOptionalString(json[keys.id]);
    if (id == null) {
      throw FormatException(
        'User needs "${keys.id}"; set UserJsonKeys(id: ...) if your API '
        'names it differently. Got the fields ${json.keys.toList()}.',
      );
    }
    return ChatUser(
      id: id,
      name: readOptionalString(json[keys.name]) ?? '',
      avatarUrl: readOptionalString(json[keys.avatarUrl]),
      metadata: readMap(json[keys.metadata]),
    );
  }

  /// The user id (JSON `id`), matching `Message.authorId` and
  /// `RoomMember.userId`.
  final String id;

  /// The display name (JSON `name`).
  final String name;

  /// The profile picture (JSON `avatar_url`). Without it the avatar shows
  /// the name's initials.
  final String? avatarUrl;

  /// App extras (role, verified badge, ...), round-tripped untouched.
  final Map<String, Object?> metadata;

  /// A copy with the given fields replaced; null keeps the current value.
  ChatUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    Map<String, Object?>? metadata,
  }) {
    return ChatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  /// This user as JSON with the names of [keys]; null and empty fields are
  /// left out.
  Map<String, Object?> toJson({UserJsonKeys keys = const UserJsonKeys()}) {
    return withoutNulls({
      keys.id: id,
      keys.name: name,
      keys.avatarUrl: avatarUrl,
      keys.metadata: metadata.isEmpty ? null : metadata,
    });
  }

  @override
  bool operator ==(Object other) {
    return other is ChatUser &&
        other.id == id &&
        other.name == name &&
        other.avatarUrl == avatarUrl &&
        deepEquality.equals(other.metadata, metadata);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, avatarUrl, deepEquality.hash(metadata));

  @override
  String toString() => 'ChatUser($id, $name)';
}
