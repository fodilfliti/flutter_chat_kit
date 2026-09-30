import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// A person who can author messages.
@immutable
class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.metadata = const {},
  });

  factory ChatUser.fromJson(Map<String, Object?> json) {
    return ChatUser(
      id: readString(json, 'id'),
      name: readOptionalString(json['name']) ?? '',
      avatarUrl: readOptionalString(json['avatar_url']),
      metadata: readMap(json['metadata']),
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;

  /// App extras (role, verified badge, ...), round-tripped untouched.
  final Map<String, Object?> metadata;

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

  Map<String, Object?> toJson() {
    return withoutNulls({
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'metadata': metadata.isEmpty ? null : metadata,
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
