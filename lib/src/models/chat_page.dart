import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// One page returned by a `ChatSource` fetch.
@immutable
class ChatPage<T> {
  const ChatPage({required this.items, required this.hasMore});

  const ChatPage.empty() : items = const [], hasMore = false;

  final List<T> items;

  /// Whether another page exists in the direction that was fetched.
  final bool hasMore;

  @override
  bool operator ==(Object other) {
    return other is ChatPage<T> &&
        other.hasMore == hasMore &&
        deepEquality.equals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(hasMore, deepEquality.hash(items));

  @override
  String toString() => 'ChatPage(${items.length} items, hasMore: $hasMore)';
}
