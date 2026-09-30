import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';

/// Which rooms one inbox list shows, for example a "Chats" tab with direct
/// rooms and a "Groups" tab.
///
/// The kit always applies the filter to its local cache. It also passes it
/// to `ChatDataSource.fetchRooms`, so the backend can return only matching
/// rooms; a backend that ignores it still works, because non-matching rooms
/// are hidden and paging continues until the list fills.
@immutable
class RoomFilter {
  const RoomFilter({
    this.types,
    this.labels,
    this.excludeLabels,
    this.unreadOnly = false,
    this.where,
  });

  /// Every room.
  static const all = RoomFilter();

  /// One-to-one conversations.
  static const direct = RoomFilter(types: {RoomType.direct});

  /// Group rooms and channels.
  static const groups = RoomFilter(types: {RoomType.group, RoomType.channel});

  /// Room types to include; null means any type.
  final Set<RoomType>? types;

  /// Include rooms with at least one of these labels; null means any.
  final Set<String>? labels;

  /// Exclude rooms with any of these labels, for example `{'archived'}` for
  /// the main list.
  final Set<String>? excludeLabels;

  /// Only rooms with unread messages. A room leaves the list once read.
  final bool unreadOnly;

  /// An extra condition checked on the device only; backends never see it.
  final bool Function(ChatRoom room)? where;

  bool get isAll =>
      types == null &&
      labels == null &&
      excludeLabels == null &&
      !unreadOnly &&
      where == null;

  bool matches(ChatRoom room) {
    final types = this.types;
    if (types != null && !types.contains(room.type)) return false;
    final labels = this.labels;
    if (labels != null && !labels.any(room.labels.contains)) return false;
    final excluded = excludeLabels;
    if (excluded != null && excluded.any(room.labels.contains)) return false;
    if (unreadOnly && room.unreadCount == 0) return false;
    return where?.call(room) ?? true;
  }

  List<ChatRoom> apply(List<ChatRoom> rooms) => isAll
      ? rooms
      : [
          for (final r in rooms)
            if (matches(r)) r,
        ];

  /// Query parameters for a REST backend: `types=direct,group`,
  /// `labels=a,b`, `exclude_labels=archived`, `unread=true`. [where] is
  /// never sent.
  Map<String, String> toQuery() {
    final types = this.types;
    final labels = this.labels;
    final excluded = excludeLabels;
    return {
      if (types != null)
        'types': (types.map((t) => t.name).toList()..sort()).join(','),
      if (labels != null) 'labels': (labels.toList()..sort()).join(','),
      if (excluded != null)
        'exclude_labels': (excluded.toList()..sort()).join(','),
      if (unreadOnly) 'unread': 'true',
    };
  }

  RoomFilter copyWith({
    Set<RoomType>? types,
    Set<String>? labels,
    Set<String>? excludeLabels,
    bool? unreadOnly,
    bool Function(ChatRoom room)? where,
  }) {
    return RoomFilter(
      types: types ?? this.types,
      labels: labels ?? this.labels,
      excludeLabels: excludeLabels ?? this.excludeLabels,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      where: where ?? this.where,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RoomFilter &&
        deepEquality.equals(other.types, types) &&
        deepEquality.equals(other.labels, labels) &&
        deepEquality.equals(other.excludeLabels, excludeLabels) &&
        other.unreadOnly == unreadOnly &&
        other.where == where;
  }

  @override
  int get hashCode => Object.hash(
    deepEquality.hash(types),
    deepEquality.hash(labels),
    deepEquality.hash(excludeLabels),
    unreadOnly,
    where,
  );

  @override
  String toString() =>
      'RoomFilter(${toQuery()}${where == null ? '' : ', where'})';
}
