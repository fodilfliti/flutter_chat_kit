import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/cache/chat_cache.dart';
import 'package:flutter_chat_pro/src/config/chat_config.dart';
import 'package:flutter_chat_pro/src/models/chat_event.dart';
import 'package:flutter_chat_pro/src/models/chat_page.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';
import 'package:flutter_chat_pro/src/models/presence.dart';
import 'package:flutter_chat_pro/src/models/room_filter.dart';
import 'package:flutter_chat_pro/src/models/typing.dart';
import 'package:flutter_chat_pro/src/source/chat_source.dart';
import 'package:flutter_chat_pro/src/source/chat_user_resolver.dart';
import 'package:flutter_chat_pro/src/sync/retry_policy.dart';
import 'package:flutter_chat_pro/src/sync/room_sync_state.dart';
import 'package:flutter_chat_pro/src/sync/room_window.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// Result of `ChatRepository.fetchRooms`: whether more rooms exist and the
/// cursor to pass as `after` for the next page.
typedef RoomsPageInfo = ({bool hasMore, RoomCursor? next});

/// Reads from `ChatSource` and writes into `ChatCache`. The UI watches the
/// cache; nothing here keeps message lists in memory.
///
/// Per room, `RoomSyncState` tracks the contiguous range of history that
/// ends at the newest message (`oldest` .. `newest`). Windows handed to the
/// UI never extend past that range, so a hole in the cache is never shown.
///
/// Source failures (`AppFailure`) are rethrown to the caller; cache writes
/// are transactional and the sync state only moves after data is stored.
///
/// Live streams (`ChatSource.events`) that fail or end are subscribed again
/// with [reconnectPolicy] backoff, and the room or inbox refetches what it
/// missed. Their errors go to [errors].
class ChatRepository {
  ChatRepository({
    required this.currentUserId,
    required this._source,
    required this._cache,
    ChatUserResolver? users,
    this._config = const ChatConfig(),
    this._clock = DateTime.now,
    this.maxGapPages = 5,
    this.maxJumpPages = 20,
    this.userBatchWindow = const Duration(milliseconds: 20),
    this.reconnectPolicy = const RetryPolicy(
      maxAttempts: 8,
      base: Duration(seconds: 1),
      max: Duration(minutes: 1),
    ),
    this.onActiveRoomChanged,
  }) : _resolver = users;

  /// Called with the most recently opened room that is still open (null
  /// when none is), each time it changes. Backs `ChatKit.activeRoomId`.
  final void Function(String? roomId)? onActiveRoomChanged;

  final String currentUserId;
  final ChatSource _source;
  final ChatCache _cache;
  final ChatUserResolver? _resolver;
  final ChatConfig _config;
  final DateTime Function() _clock;

  /// Pages fetched, newest first, when reopening a room before the rest of
  /// the gap is left to paging. A room that missed 1000 messages costs at
  /// most this many requests to open.
  final int maxGapPages;

  /// Pages of older messages fetched to find a jump target when the source
  /// has no `fetchAround`.
  final int maxJumpPages;

  /// User lookups requested within this window share one resolver call.
  final Duration userBatchWindow;

  /// Backoff between attempts to subscribe again to a live stream that
  /// failed or ended. After `maxAttempts` in a row without an event the
  /// stream stays down until [reconnect].
  final RetryPolicy reconnectPolicy;

  final Map<String, _OpenRoom> _rooms = {};
  final List<String> _openOrder = [];
  final Map<String, Future<void>> _locks = {};
  final _errors = StreamController<AppFailure>.broadcast();
  StreamSubscription<ChatEvent>? _inboxSub;
  Timer? _inboxRetry;
  int _inboxAttempts = 0;
  int _inboxRefs = 0;
  final List<Future<void> Function()> _inboxResyncs = [];
  Future<void> _inboxChain = Future.value();
  bool _disposed = false;

  final Map<String, TypingState> _typing = {};
  final Map<(String, String), Timer> _typingTimers = {};
  final _typingController = StreamController<TypingState>.broadcast();

  final Map<String, Presence> _presence = {};
  final _presenceController = StreamController<Presence>.broadcast();

  final Set<String> _userBatch = {};
  Completer<void>? _userBatchCompleter;
  final Map<String, Future<void>> _usersInFlight = {};
  final _usersController = StreamController<List<ChatUser>>.broadcast();

  int get _pageSize => _config.pageSize;

  /// Failures of live streams and of the background refetches that follow
  /// a reconnect. Nothing here needs handling; listen to log them.
  Stream<AppFailure> get errors => _errors.stream;

  // ---------------------------------------------------------------- inbox

  /// Cached rooms matching [search] and [filter], pinned first, then most
  /// recently updated.
  Stream<List<ChatRoom>> watchRooms({
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) {
    final rooms = _cache.watchRooms(search: search);
    return filter.isAll ? rooms : rooms.map(filter.apply);
  }

  Stream<ChatRoom?> watchRoom(String roomId) => _cache.watchRoom(roomId);

  /// Fetches one page of rooms into the cache: the first page, or the one
  /// after [after]. Pass the returned `next` as [after] for the following
  /// page. Stateless, so several inbox lists can page independently.
  Future<RoomsPageInfo> fetchRooms({
    RoomCursor? after,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) async {
    final page = await _source.fetchRooms(
      after: after,
      limit: _config.roomsPageSize,
      search: search,
      filter: filter,
    );
    await putUsers(page.users);
    await _cache.upsertRooms(page.items);
    if (page.items.isEmpty) return (hasMore: false, next: after);
    return (hasMore: page.hasMore, next: page.items.last.cursor);
  }

  /// Subscribes to inbox-level events (room changes, presence). Calls are
  /// counted; each must be matched by [closeInbox] with the same
  /// [onResync]. [resync] calls every registered [onResync] (usually the
  /// controller refetching its first page).
  void openInbox({Future<void> Function()? onResync}) {
    _inboxRefs++;
    if (onResync != null) _inboxResyncs.add(onResync);
    if (_inboxSub == null && _inboxRetry == null) _listenInbox();
  }

  Future<void> closeInbox({Future<void> Function()? onResync}) async {
    if (_inboxRefs == 0) return;
    if (onResync != null) _inboxResyncs.remove(onResync);
    _inboxRefs--;
    if (_inboxRefs > 0) return;
    _inboxRetry?.cancel();
    _inboxRetry = null;
    _inboxAttempts = 0;
    final sub = _inboxSub;
    _inboxSub = null;
    await sub?.cancel();
  }

  void _listenInbox() {
    _inboxSub = _source.events().listen(
      (event) {
        _inboxAttempts = 0;
        _inboxChain = _inboxChain.then((_) => _guard(event));
      },
      onError: (Object error, StackTrace stack) {
        _report(error, stack);
        _inboxLost();
      },
      onDone: _inboxLost,
      cancelOnError: true,
    );
  }

  void _inboxLost() {
    _inboxSub = null;
    if (_disposed || _inboxRefs == 0) return;
    if (++_inboxAttempts > reconnectPolicy.maxAttempts) return;
    _inboxRetry?.cancel();
    _inboxRetry = Timer(reconnectPolicy.delay(_inboxAttempts), () {
      _inboxRetry = null;
      if (_disposed || _inboxRefs == 0 || _inboxSub != null) return;
      _listenInbox();
      unawaited(_refreshInboxes());
    });
  }

  /// Refetches the first page of every open inbox list; failures go to
  /// [errors].
  Future<void> _refreshInboxes() async {
    for (final refresh in _inboxRefreshes) {
      try {
        await refresh();
      } on Object catch (error, stack) {
        _report(error, stack);
      }
    }
  }

  List<Future<void> Function()> get _inboxRefreshes => _inboxResyncs.isEmpty
      ? <Future<void> Function()>[fetchRooms]
      : [..._inboxResyncs];

  /// Subscribes again to every live stream that is down: one that failed
  /// or ended and is waiting for its backoff, or gave up. Healthy streams
  /// are left alone. Follow with [resync] to fetch what was missed.
  void reconnect() {
    if (_disposed) return;
    if (_inboxRefs > 0 && _inboxSub == null) {
      _inboxRetry?.cancel();
      _inboxRetry = null;
      _inboxAttempts = 0;
      _listenInbox();
    }
    for (final MapEntry(key: roomId, value: room) in _rooms.entries) {
      if (room.sub != null) continue;
      room
        ..retry?.cancel()
        ..retry = null
        ..attempts = 0
        ..synced = false;
      _listenRoom(roomId, room);
    }
  }

  void _listenRoom(String roomId, _OpenRoom room) {
    room.sub = _source
        .events(roomId: roomId)
        .listen(
          (event) {
            room.attempts = 0;
            room.chain = room.chain.then((_) => _guard(event));
          },
          onError: (Object error, StackTrace stack) {
            _report(error, stack);
            _roomLost(roomId, room);
          },
          onDone: () => _roomLost(roomId, room),
          cancelOnError: true,
        );
  }

  void _roomLost(String roomId, _OpenRoom room) {
    room
      ..sub = null
      ..synced = false;
    if (_disposed || _rooms[roomId] != room) return;
    if (++room.attempts > reconnectPolicy.maxAttempts) return;
    room.retry?.cancel();
    room.retry = Timer(reconnectPolicy.delay(room.attempts), () {
      room.retry = null;
      if (_disposed || _rooms[roomId] != room || room.sub != null) return;
      _listenRoom(roomId, room);
      unawaited(
        _locked(roomId, () => _sync(roomId)).then((_) {}, onError: _report),
      );
    });
  }

  void _report(Object error, StackTrace stack) {
    if (_disposed) return;
    _errors.add(
      error is AppFailure ? error : UnknownFailure(cause: error, trace: stack),
    );
  }

  // ---------------------------------------------------------------- rooms

  /// The window to show from the cache before the room has synced.
  Future<LatestWindow> latestWindow(String roomId) async {
    final state = await _cache.syncState(roomId);
    if (state == null) return const LatestWindow();
    final newest = await _cache.messages(
      roomId,
      from: state.oldest,
      limit: _pageSize,
    );
    if (newest.length < _pageSize) {
      return LatestWindow(from: state.oldest, hasMoreOlder: state.hasMoreOlder);
    }
    final from = newest.last.cursor;
    return LatestWindow(
      from: from,
      hasMoreOlder: await _hasOlder(roomId, state, from),
    );
  }

  /// Syncs the room (fills the gap since the last visit, or fetches the
  /// latest page) and subscribes to its events. Calls are counted; each
  /// must be matched by [closeRoom]. Returns the window to show.
  Future<LatestWindow> openRoom(String roomId) async {
    final room = _rooms.putIfAbsent(roomId, _OpenRoom.new);
    if (room.refs++ == 0) {
      _openOrder
        ..remove(roomId)
        ..add(roomId);
      onActiveRoomChanged?.call(roomId);
    }
    if (room.sub == null && room.retry == null) _listenRoom(roomId, room);
    await _locked(roomId, () => _sync(roomId));
    return await latestWindow(roomId);
  }

  Future<void> closeRoom(String roomId) async {
    final room = _rooms[roomId];
    if (room == null) return;
    room.refs--;
    if (room.refs > 0) return;
    _rooms.remove(roomId);
    final wasActive = _openOrder.lastOrNull == roomId;
    _openOrder.remove(roomId);
    if (wasActive) onActiveRoomChanged?.call(_openOrder.lastOrNull);
    await room.cancel();
    _clearTyping(roomId);
  }

  bool isOpen(String roomId) => _rooms.containsKey(roomId);

  /// Messages of [window], newest first.
  Stream<List<Message>> watchMessages(String roomId, RoomWindow window) {
    return switch (window) {
      LatestWindow(:final from) => _cache.watchMessages(roomId, from: from),
      DetachedWindow(:final oldest, :final newest) => _cache.watchMessages(
        roomId,
        from: oldest,
        to: newest,
      ),
    };
  }

  /// Extends [window] by up to one page of older messages, from the cache
  /// when it has them contiguously, otherwise from the source.
  Future<RoomWindow> loadOlder(String roomId, RoomWindow window) {
    return _locked(
      roomId,
      () => switch (window) {
        LatestWindow() => _loadOlderLatest(roomId, window),
        DetachedWindow() => _loadOlderDetached(roomId, window),
      },
    );
  }

  /// Extends a [DetachedWindow] by one page of newer messages. Once it
  /// reaches the synced range it becomes a [LatestWindow].
  Future<RoomWindow> loadNewer(String roomId, RoomWindow window) {
    return switch (window) {
      LatestWindow() => Future.value(window),
      DetachedWindow() => _locked(
        roomId,
        () => _loadNewerDetached(roomId, window),
      ),
    };
  }

  /// A window containing [messageId]. Returns [current] when it already
  /// contains it, and null when the message can't be found.
  Future<RoomWindow?> jumpTo(
    String roomId,
    String messageId, {
    RoomWindow? current,
  }) {
    return _locked(roomId, () => _jumpTo(roomId, messageId, current));
  }

  /// Call when the connection dropped: events may be missed, so open rooms
  /// stop advancing their synced range until [resync].
  void connectionLost() {
    for (final room in _rooms.values) {
      room.synced = false;
    }
  }

  /// Fills the gap of every open room (after a reconnect) and refreshes
  /// the first page of every open inbox list. Failures leave the room
  /// unsynced for the next attempt; the first one is rethrown.
  Future<void> resync() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final roomId in _rooms.keys.toList()) {
      try {
        await _locked(roomId, () => _sync(roomId));
      } on AppFailure catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      }
    }
    if (_inboxRefs > 0) {
      for (final refresh in _inboxRefreshes) {
        try {
          await refresh();
        } on AppFailure catch (e, st) {
          firstError ??= e;
          firstStack ??= st;
        }
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  // --------------------------------------------------------- room actions

  /// Moves the current user's read pointer to [upTo] and clears the room's
  /// unread count, in the cache first, then on the source.
  Future<void> markRead(String roomId, MessageCursor upTo) async {
    await _cache.updatePointers(roomId, currentUserId, readAt: upTo.createdAt);
    final room = await _cache.watchRoom(roomId).first;
    if (room != null && room.unreadCount != 0) {
      await _cache.upsertRooms([room.copyWith(unreadCount: 0)]);
    }
    await _source.markRead(roomId, upTo);
  }

  /// Pins or mutes a room: the cache changes at once and is restored when
  /// the source rejects it.
  Future<void> setRoomFlags(String roomId, {bool? pinned, bool? muted}) async {
    final room = await _cache.watchRoom(roomId).first;
    if (room == null) return;
    await _cache.upsertRooms([room.copyWith(pinned: pinned, muted: muted)]);
    try {
      if (pinned != null && pinned != room.pinned) {
        await _source.setPinned(roomId, pinned: pinned);
      }
      if (muted != null && muted != room.muted) {
        await _source.setMuted(roomId, muted: muted);
      }
    } on AppFailure {
      await _cache.upsertRooms([room]);
      rethrow;
    }
  }

  /// Tells the other members whether the current user is typing.
  Future<void> setTyping(String roomId, {required bool typing}) =>
      _source.setTyping(roomId, typing: typing);

  // --------------------------------------------------------------- typing

  TypingState typing(String roomId) =>
      _typing[roomId] ?? TypingState(roomId: roomId);

  /// Changes of who is typing in [roomId] (the current user excluded).
  /// Entries expire after `ChatConfig.typingTimeout` without an update.
  Stream<TypingState> watchTyping(String roomId) =>
      _typingController.stream.where((t) => t.roomId == roomId);

  /// Typing changes in every room, for the inbox.
  Stream<TypingState> get typingChanges => _typingController.stream;

  // ------------------------------------------------------------- presence

  Presence? presence(String userId) => _presence[userId];

  Stream<Presence> watchPresence(String userId) =>
      _presenceController.stream.where((p) => p.userId == userId);

  /// Every presence change received while the inbox is open.
  Stream<Presence> get presenceChanges => _presenceController.stream;

  // ---------------------------------------------------------------- users

  /// Users by id: cached ones, refreshed through the resolver when missing
  /// or older than `ChatConfig.userCacheTtl`. Resolver failures fall back
  /// to what the cache has.
  Future<Map<String, ChatUser>> users(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    if (_resolver != null) {
      final stale = await _cache.staleUsers(
        ids,
        olderThan: _clock().subtract(_config.userCacheTtl),
      );
      if (stale.isNotEmpty) {
        try {
          await Future.wait([
            for (final id in stale) _usersInFlight[id] ??= _queueUser(id),
          ]);
        } on AppFailure {
          // Serve what the cache has; the stale entries retry next time.
        }
      }
    }
    return await _cache.users(ids);
  }

  /// Stores users the backend sent (with a page, an event or from the app)
  /// as fresh, and emits the ones that are new or changed on
  /// [userChanges].
  Future<void> putUsers(List<ChatUser> users) async {
    if (users.isEmpty || _disposed) return;
    final byId = {for (final user in users) user.id: user};
    final before = await _cache.users(byId.keys.toSet());
    await _cache.upsertUsers(byId.values.toList());
    final changed = [
      for (final user in byId.values)
        if (before[user.id] != user) user,
    ];
    if (changed.isNotEmpty && !_disposed) _usersController.add(changed);
  }

  /// Users stored with a new name, avatar or metadata, for open screens.
  Stream<List<ChatUser>> get userChanges => _usersController.stream;

  Future<void> dispose() async {
    _disposed = true;
    for (final room in _rooms.values) {
      await room.cancel();
    }
    _rooms.clear();
    _openOrder.clear();
    _inboxRetry?.cancel();
    _inboxRetry = null;
    await _inboxSub?.cancel();
    _inboxSub = null;
    _inboxResyncs.clear();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    await _typingController.close();
    await _presenceController.close();
    await _usersController.close();
    await _errors.close();
  }

  // ------------------------------------------------------------- internal

  Future<T> _locked<T>(String roomId, Future<T> Function() body) {
    final previous = _locks[roomId] ?? Future<void>.value();
    final result = previous.then((_) => body());
    _locks[roomId] = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<ChatPage<Message>> _fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    final page = await _source.fetchMessages(
      roomId,
      before: before,
      after: after,
      limit: limit,
    );
    await putUsers(page.users);
    return page;
  }

  Future<void> _sync(String roomId) async {
    final state = await _cache.syncState(roomId);
    final newest = state?.newest;
    if (state == null || newest == null) {
      await _restartFromLatest(roomId);
    } else {
      await _fillGap(roomId, state, newest);
    }
    _rooms[roomId]?.synced = true;
    final keep = _config.maxCachedMessagesPerRoom;
    if (keep != null) await _cache.trim(roomId, keep: keep);
  }

  /// Fetches newest first and pages back with `before` until it reaches the
  /// cached [newest]: one request when less than a page was missed, and the
  /// newest messages are on screen first when more was. A gap wider than
  /// [maxGapPages] pages is not walked to the end: the fetched pages become
  /// the synced range, and older cached messages come back through paging.
  Future<void> _fillGap(
    String roomId,
    RoomSyncState state,
    MessageCursor newest,
  ) async {
    MessageCursor? top;
    MessageCursor? before;
    for (var pages = 1; ; pages++) {
      final page = await _fetchMessages(
        roomId,
        before: before,
        limit: _pageSize,
      );
      await _cache.upsertMessages(page.items);
      top ??= page.items.firstOrNull?.cursor;
      final last = page.items.lastOrNull?.cursor;
      if (last == null || !last.isAfter(newest) || !page.hasMore) {
        await _cache.saveSyncState(
          state.copyWith(
            newest: top != null && top.isAfter(newest) ? top : newest,
            syncedAt: _clock(),
          ),
        );
        return;
      }
      if (pages >= maxGapPages) {
        await _cache.saveSyncState(
          RoomSyncState(
            roomId: roomId,
            newest: top,
            oldest: last,
            syncedAt: _clock(),
          ),
        );
        return;
      }
      before = last;
    }
  }

  /// Fetches the latest page and makes it the synced range. Older cached
  /// messages stay but are only shown again once paging reconnects them.
  Future<void> _restartFromLatest(String roomId) async {
    final page = await _fetchMessages(roomId, limit: _pageSize);
    await _cache.upsertMessages(page.items);
    await _cache.saveSyncState(
      RoomSyncState(
        roomId: roomId,
        newest: page.items.isEmpty ? null : page.items.first.cursor,
        oldest: page.items.isEmpty ? null : page.items.last.cursor,
        hasMoreOlder: page.hasMore,
        syncedAt: _clock(),
      ),
    );
  }

  Future<RoomWindow> _loadOlderLatest(String roomId, LatestWindow w) async {
    var state = await _cache.syncState(roomId);
    if (state == null) return w;
    final from = w.from ?? state.oldest;
    if (from == null) return const LatestWindow(hasMoreOlder: false);

    var older = await _olderContiguous(roomId, state, from, _pageSize);
    final oldest = state.oldest;
    if (older.length < _pageSize && state.hasMoreOlder && oldest != null) {
      final page = await _fetchMessages(
        roomId,
        before: oldest,
        limit: _pageSize,
      );
      await _cache.upsertMessages(page.items);
      state = RoomSyncState(
        roomId: roomId,
        newest: state.newest,
        oldest: page.items.isEmpty ? oldest : page.items.last.cursor,
        hasMoreOlder: page.hasMore,
        syncedAt: state.syncedAt,
      );
      await _cache.saveSyncState(state);
      older = await _olderContiguous(roomId, state, from, _pageSize);
    }
    final newFrom = older.isEmpty ? from : older.last.cursor;
    return LatestWindow(
      from: newFrom,
      hasMoreOlder: await _hasOlder(roomId, state, newFrom),
    );
  }

  Future<RoomWindow> _loadOlderDetached(String roomId, DetachedWindow w) async {
    if (!w.hasMoreOlder) return w;
    final page = await _fetchMessages(
      roomId,
      before: w.oldest,
      limit: _pageSize,
    );
    await _cache.upsertMessages(page.items);
    return DetachedWindow(
      oldest: page.items.isEmpty ? w.oldest : page.items.last.cursor,
      newest: w.newest,
      hasMoreOlder: page.hasMore,
      hasMoreNewer: w.hasMoreNewer,
    );
  }

  Future<RoomWindow> _loadNewerDetached(String roomId, DetachedWindow w) async {
    final page = await _fetchMessages(
      roomId,
      after: w.newest,
      limit: _pageSize,
    );
    await _cache.upsertMessages(page.items);
    final newest = page.items.isEmpty ? w.newest : page.items.first.cursor;
    final state = await _cache.syncState(roomId);
    final syncedOldest = state?.oldest;
    final reachedSynced =
        syncedOldest != null && !newest.isBefore(syncedOldest);
    if (page.hasMore && !reachedSynced) {
      return DetachedWindow(
        oldest: w.oldest,
        newest: newest,
        hasMoreOlder: w.hasMoreOlder,
      );
    }
    await _extendSynced(
      roomId,
      state,
      oldest: w.oldest,
      hasMoreOlder: w.hasMoreOlder,
      newest: page.hasMore ? null : newest,
    );
    return LatestWindow(from: w.oldest, hasMoreOlder: w.hasMoreOlder);
  }

  Future<RoomWindow?> _jumpTo(
    String roomId,
    String messageId,
    RoomWindow? current,
  ) async {
    final state = await _cache.syncState(roomId);
    final cached = await _cache.messageByAnyId(messageId);
    if (cached != null && cached.roomId == roomId) {
      final at = cached.cursor;
      if (current is DetachedWindow &&
          !at.isBefore(current.oldest) &&
          !at.isAfter(current.newest)) {
        return current;
      }
      if (state != null && _contiguous(state, at)) {
        return await _latestIncluding(roomId, state, at, current);
      }
    }

    final around = await _source.fetchAround(
      roomId,
      messageId,
      limit: _pageSize,
    );
    if (around != null) {
      await putUsers(around.users);
      return await _placeAround(roomId, messageId, around, current);
    }

    var synced = state;
    for (var pages = 0; pages < maxJumpPages; pages++) {
      final oldest = synced?.oldest;
      if (synced == null || oldest == null || !synced.hasMoreOlder) break;
      final page = await _fetchMessages(
        roomId,
        before: oldest,
        limit: _pageSize,
      );
      await _cache.upsertMessages(page.items);
      synced = RoomSyncState(
        roomId: roomId,
        newest: synced.newest,
        oldest: page.items.isEmpty ? oldest : page.items.last.cursor,
        hasMoreOlder: page.hasMore,
        syncedAt: synced.syncedAt,
      );
      await _cache.saveSyncState(synced);
      for (final m in page.items) {
        if (m.matches(messageId)) {
          return await _latestIncluding(roomId, synced, m.cursor, current);
        }
      }
    }
    return null;
  }

  Future<RoomWindow?> _placeAround(
    String roomId,
    String messageId,
    ChatPage<Message> around,
    RoomWindow? current,
  ) async {
    Message? target;
    for (final m in around.items) {
      if (m.matches(messageId)) target = m;
    }
    if (target == null) return null;
    await _cache.upsertMessages(around.items);
    final oldest = around.items.last.cursor;
    final newest = around.items.first.cursor;
    final state = await _cache.syncState(roomId);
    final syncedOldest = state?.oldest;
    if (state != null &&
        (syncedOldest == null || !newest.isBefore(syncedOldest))) {
      final extended = await _extendSynced(
        roomId,
        state,
        oldest: oldest,
        hasMoreOlder: around.hasMore,
      );
      return await _latestIncluding(roomId, extended, target.cursor, current);
    }
    return DetachedWindow(
      oldest: oldest,
      newest: newest,
      hasMoreOlder: around.hasMore,
    );
  }

  /// Grows the synced range down to [oldest] (and up to [newest]) after a
  /// fetched slice was found to connect with it.
  Future<RoomSyncState> _extendSynced(
    String roomId,
    RoomSyncState? state, {
    required MessageCursor oldest,
    required bool hasMoreOlder,
    MessageCursor? newest,
  }) async {
    final current = state ?? RoomSyncState(roomId: roomId);
    final currentOldest = current.oldest;
    final lowers =
        current.newest == null ||
        (currentOldest != null && oldest.isBefore(currentOldest));
    final currentNewest = current.newest;
    final next = RoomSyncState(
      roomId: roomId,
      newest:
          newest != null &&
              (currentNewest == null || newest.isAfter(currentNewest))
          ? newest
          : currentNewest,
      oldest: lowers ? oldest : currentOldest,
      hasMoreOlder: lowers ? hasMoreOlder : current.hasMoreOlder,
      syncedAt: current.syncedAt,
    );
    await _cache.saveSyncState(next);
    return next;
  }

  /// A latest window that shows [target] with up to half a page of older
  /// context, keeping [current] when it already reaches further.
  Future<LatestWindow> _latestIncluding(
    String roomId,
    RoomSyncState state,
    MessageCursor target,
    RoomWindow? current,
  ) async {
    if (current is LatestWindow) {
      final currentFrom = current.from;
      if (currentFrom == null || !currentFrom.isAfter(target)) return current;
    }
    final older = await _olderContiguous(roomId, state, target, _pageSize ~/ 2);
    final from = older.isEmpty ? target : older.last.cursor;
    return LatestWindow(
      from: from,
      hasMoreOlder: await _hasOlder(roomId, state, from),
    );
  }

  bool _contiguous(RoomSyncState state, MessageCursor cursor) {
    final oldest = state.oldest;
    return oldest == null
        ? state.newest != null || !state.hasMoreOlder
        : !cursor.isBefore(oldest);
  }

  Future<List<Message>> _olderContiguous(
    String roomId,
    RoomSyncState state,
    MessageCursor from,
    int limit,
  ) async {
    if (limit <= 0) return const [];
    final older = await _cache.messagesBefore(roomId, from, limit);
    return older.takeWhile((m) => _contiguous(state, m.cursor)).toList();
  }

  Future<bool> _hasOlder(
    String roomId,
    RoomSyncState state,
    MessageCursor from,
  ) async {
    if (state.hasMoreOlder) return true;
    return (await _olderContiguous(roomId, state, from, 1)).isNotEmpty;
  }

  Future<void> _guard(ChatEvent event) async {
    if (_disposed) return;
    try {
      await _handle(event);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_chat_pro',
          context: ErrorDescription('while applying a realtime chat event'),
        ),
      );
    }
  }

  Future<void> _handle(ChatEvent event) async {
    switch (event) {
      case MessageChanged(:final roomId, change: Created(:final item)):
        _setTyping(roomId, item.authorId, typing: false);
        await _storeMessage(roomId, item);
      case MessageChanged(:final roomId, change: Updated(:final item)):
        await _storeMessage(roomId, item);
      case MessageChanged(change: Deleted(:final id)):
        await _cache.deleteMessage(id);
      case ReceiptChanged(
        :final roomId,
        :final userId,
        :final readAt,
        :final deliveredAt,
      ):
        await _cache.updatePointers(
          roomId,
          userId,
          readAt: readAt,
          deliveredAt: deliveredAt,
        );
      case TypingChanged(:final roomId, :final userId, :final typing):
        _setTyping(roomId, userId, typing: typing);
      case RoomChanged(change: Created(:final item) || Updated(:final item)):
        await _cache.upsertRooms([item]);
      case RoomChanged(change: Deleted(:final id)):
        await _cache.deleteRoom(id);
      case PresenceChanged(:final presence):
        _presence[presence.userId] = presence;
        _presenceController.add(presence);
      case UsersChanged(:final users):
        await putUsers(users);
    }
  }

  Future<void> _storeMessage(String roomId, Message message) async {
    await _cache.upsertMessages([message]);
    final room = _rooms[roomId];
    if (room == null || !room.synced || message.status.isLocal) return;
    await _locked(roomId, () async {
      if (!room.synced) return;
      final state = await _cache.syncState(roomId);
      if (state == null) return;
      final newest = state.newest;
      if (newest != null && !message.cursor.isAfter(newest)) return;
      await _cache.saveSyncState(state.copyWith(newest: message.cursor));
    });
  }

  void _setTyping(String roomId, String userId, {required bool typing}) {
    if (userId == currentUserId || _disposed) return;
    final key = (roomId, userId);
    _typingTimers.remove(key)?.cancel();
    if (typing) {
      _typingTimers[key] = Timer(
        _config.typingTimeout,
        () => _setTyping(roomId, userId, typing: false),
      );
    }
    final previous = this.typing(roomId);
    final next = previous.withUser(userId, typing: typing);
    if (next == previous) return;
    _typing[roomId] = next;
    _typingController.add(next);
  }

  void _clearTyping(String roomId) {
    _typingTimers.removeWhere((key, timer) {
      if (key.$1 != roomId) return false;
      timer.cancel();
      return true;
    });
    if (_typing.remove(roomId) != null && !_disposed) {
      _typingController.add(TypingState(roomId: roomId));
    }
  }

  Future<void> _queueUser(String id) {
    _userBatch.add(id);
    final completer = _userBatchCompleter ??= _scheduleUserBatch();
    // The removed future is this one: returning it from the callback would
    // make whenComplete wait on itself. Callers await it already.
    return completer.future.whenComplete(() {
      final removed = _usersInFlight.remove(id);
      if (removed != null) unawaited(removed);
    });
  }

  Completer<void> _scheduleUserBatch() {
    final completer = Completer<void>();
    Timer(userBatchWindow, () => unawaited(_flushUsers(completer)));
    return completer;
  }

  Future<void> _flushUsers(Completer<void> completer) async {
    final ids = {..._userBatch};
    _userBatch.clear();
    _userBatchCompleter = null;
    try {
      final resolved = await _resolver!.resolve(ids);
      await putUsers(resolved);
      completer.complete();
    } on Object catch (error, stack) {
      completer.completeError(error, stack);
    }
  }
}

class _OpenRoom {
  int refs = 0;
  StreamSubscription<ChatEvent>? sub;

  /// Pending resubscribe after the stream failed or ended.
  Timer? retry;

  /// Resubscribes since the last event.
  int attempts = 0;

  /// Events are applied one after another, in arrival order.
  Future<void> chain = Future.value();

  /// True while the room's range is known to be complete up to now.
  bool synced = false;

  Future<void> cancel() async {
    retry?.cancel();
    retry = null;
    await sub?.cancel();
    sub = null;
  }
}
