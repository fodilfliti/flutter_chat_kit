import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// One page returned by a `ChatSource` fetch.
@immutable
class ChatPage<T> {
  const ChatPage({
    required this.items,
    required this.hasMore,
    this.users = const [],
  });

  const ChatPage.empty() : items = const [], hasMore = false, users = const [];

  final List<T> items;

  /// Whether another page exists in the direction that was fetched.
  final bool hasMore;

  /// Names and avatars the backend returned with this page (members,
  /// authors). The kit stores them, shows them at once, and replaces the
  /// stored ones when they change, so the `ChatUserResolver` is not asked
  /// for them.
  final List<ChatUser> users;

  @override
  bool operator ==(Object other) {
    return other is ChatPage<T> &&
        other.hasMore == hasMore &&
        deepEquality.equals(other.items, items) &&
        deepEquality.equals(other.users, users);
  }

  @override
  int get hashCode =>
      Object.hash(hasMore, deepEquality.hash(items), deepEquality.hash(users));

  @override
  String toString() =>
      'ChatPage(${items.length} items, ${users.length} users, '
      'hasMore: $hasMore)';
}
