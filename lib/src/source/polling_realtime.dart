import 'dart:async';

import 'package:flutter_chat_pro/src/models/chat_event.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';
import 'package:flutter_chat_pro/src/source/chat_source.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// Realtime for backends without push (a plain REST API): polls [data]
/// while a room or the inbox is open and emits what changed.
///
/// - An open room fetches its latest page every [roomInterval] and emits
///   new messages (`Created`) and changed ones (`Updated`: edits,
///   reactions, soft deletes). When more than one page arrived between two
///   polls, it reads forward from the newest known message so no message is
///   skipped.
/// - The inbox fetches the first page of rooms every [inboxInterval] and
///   emits the rooms that changed; room members carry the read pointers,
///   so read receipts follow.
/// - Names and avatars sent with the pages (`ChatPage.users`) that are new
///   or changed are emitted as `UsersChanged`.
/// - No typing and no presence. Failed polls are skipped; the next one
///   retries.
///
/// Use soft deletes (`deletedAt`): a message that disappears from the
/// latest page cannot be told apart from one that scrolled out of it.
///
/// ```dart
/// final api = MyRestApi(); // implements ChatDataSource
/// final source = ComposedChatSource(
///   data: api,
///   realtime: PollingRealtime(api),
/// );
/// ```
///
/// See doc/adapters/rest_websocket.md and doc/adapters/mixing.md.
class PollingRealtime implements ChatRealtime {
  /// Polls [data]; intervals and page sizes default to values suited to a
  /// small REST API.
  PollingRealtime(
    this.data, {
    this.roomInterval = const Duration(seconds: 3),
    this.inboxInterval = const Duration(seconds: 15),
    this.pageSize = 30,
    this.roomsPageSize = 20,
    this.maxCatchUpPages = 10,
  });

  /// The API polled with `fetchMessages` and `fetchRooms`.
  final ChatDataSource data;

  /// Time between two polls of an open room; new messages appear at most
  /// this late. Defaults to 3 seconds. The first poll runs at once.
  final Duration roomInterval;

  /// Time between two polls of the room list while an inbox is open.
  /// Defaults to 15 seconds.
  final Duration inboxInterval;

  /// Messages fetched per room poll. Defaults to 30.
  final int pageSize;

  /// Rooms fetched per inbox poll. Defaults to 20.
  final int roomsPageSize;

  /// Upper bound of forward pages read after a burst, per poll. Defaults
  /// to 10.
  final int maxCatchUpPages;

  @override
  Stream<ChatEvent> events({String? roomId}) {
    if (roomId == null) return _every(inboxInterval, _inboxPoller());
    return _every(roomInterval, _roomPoller(roomId), immediate: true);
  }

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {}

  Stream<ChatEvent> _every(
    Duration interval,
    Future<List<ChatEvent>> Function() poll, {
    bool immediate = false,
  }) {
    Timer? timer;
    var active = false;
    var busy = false;
    late final StreamController<ChatEvent> out;

    Future<void> tick() async {
      if (busy || !active) return;
      busy = true;
      try {
        final events = await poll();
        if (active) events.forEach(out.add);
      } on AppFailure {
        // Offline or a server error: the next tick tries again.
      } finally {
        busy = false;
      }
    }

    out = StreamController<ChatEvent>(
      onListen: () {
        active = true;
        timer = Timer.periodic(interval, (_) => unawaited(tick()));
        if (immediate) unawaited(tick());
      },
      onCancel: () {
        active = false;
        timer?.cancel();
      },
    );
    return out.stream;
  }

  Future<List<ChatEvent>> Function() _roomPoller(String roomId) {
    final known = <String, Message>{};
    final knownUsers = <String, ChatUser>{};
    MessageCursor? newest;

    return () async {
      final page = await data.fetchMessages(roomId, limit: pageSize);
      final fetched = [...page.items];
      final users = [...page.users];
      final since = newest;
      if (since != null &&
          page.hasMore &&
          page.items.isNotEmpty &&
          page.items.last.cursor.isAfter(since)) {
        final forward = await _catchUp(roomId, since);
        fetched.addAll(forward.messages);
        users.addAll(forward.users);
      }

      final byId = {for (final m in fetched) m.id: m};
      final ordered = byId.values.toList()
        ..sort((a, b) => a.cursor.compareTo(b.cursor));
      final events = <ChatEvent>[?_changedUsers(users, knownUsers)];
      for (final m in ordered) {
        final previous = known[m.id];
        if (previous == m) continue;
        known[m.id] = m;
        events.add(
          MessageChanged(
            roomId: roomId,
            change: previous == null ? Created(m) : Updated(m),
          ),
        );
        final current = newest;
        if (current == null || m.cursor.isAfter(current)) newest = m.cursor;
      }
      _trim(known);
      return events;
    };
  }

  /// Messages newer than [since], oldest first, up to [maxCatchUpPages],
  /// with the users those pages carried.
  Future<({List<Message> messages, List<ChatUser> users})> _catchUp(
    String roomId,
    MessageCursor since,
  ) async {
    final forward = <Message>[];
    final users = <ChatUser>[];
    var cursor = since;
    for (var i = 0; i < maxCatchUpPages; i++) {
      final page = await data.fetchMessages(
        roomId,
        after: cursor,
        limit: pageSize,
      );
      final oldestFirst = page.items.reversed.toList();
      forward.addAll(oldestFirst);
      users.addAll(page.users);
      if (!page.hasMore || oldestFirst.isEmpty) break;
      cursor = oldestFirst.last.cursor;
    }
    return (messages: forward, users: users);
  }

  /// A [UsersChanged] with the users not seen yet or changed since the last
  /// poll, or null.
  UsersChanged? _changedUsers(
    List<ChatUser> users,
    Map<String, ChatUser> known,
  ) {
    final changed = <ChatUser>[];
    for (final user in users) {
      if (known[user.id] == user) continue;
      known[user.id] = user;
      changed.add(user);
    }
    return changed.isEmpty ? null : UsersChanged(changed);
  }

  /// Keeps memory bounded: only recent messages can change on screen.
  void _trim(Map<String, Message> known) {
    final keep = pageSize * 4;
    if (known.length <= keep) return;
    final oldest = known.values.toList()
      ..sort((a, b) => a.cursor.compareTo(b.cursor));
    for (final m in oldest.take(known.length - keep)) {
      known.remove(m.id);
    }
  }

  Future<List<ChatEvent>> Function() _inboxPoller() {
    final known = <String, ChatRoom>{};
    final knownUsers = <String, ChatUser>{};
    return () async {
      final page = await data.fetchRooms(limit: roomsPageSize);
      final events = <ChatEvent>[?_changedUsers(page.users, knownUsers)];
      for (final room in page.items.reversed) {
        if (known[room.id] == room) continue;
        known[room.id] = room;
        events.add(RoomChanged(Updated(room)));
      }
      return events;
    };
  }
}
