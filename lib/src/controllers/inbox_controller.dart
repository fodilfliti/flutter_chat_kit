import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/controllers/chat_kit.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';
import 'package:flutter_chat_kit/src/models/room_filter.dart';
import 'package:flutter_chat_kit/src/models/typing.dart';
import 'package:flutter_chat_kit/src/sync/chat_repository.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// State of the room list: cached rooms at once, then the first page from
/// the source, search, paging, pin and mute. Create with `ChatKit.inbox()`
/// and dispose when the screen goes away.
///
/// Several controllers can live side by side (a "Chats" tab and a "Groups"
/// tab): each has its own [filter], search, paging and [totalUnread], and
/// all of them share the cache and one inbox event subscription.
class InboxController extends ChangeNotifier {
  InboxController(this.kit, {this._filter = RoomFilter.all})
    : _repository = kit.repository {
    _repository.openInbox(onResync: _resync);
    _presenceSub = _repository.presenceChanges.listen(_onPresence);
    _typingSub = _repository.typingChanges.listen(_onTyping);
    _watch();
    unawaited(refresh());
  }

  final ChatKit kit;
  final ChatRepository _repository;

  StreamSubscription<List<ChatRoom>>? _roomsSub;
  StreamSubscription<Presence>? _presenceSub;
  StreamSubscription<TypingState>? _typingSub;
  Timer? _searchTimer;
  bool _disposed = false;
  int _refreshSeq = 0;

  List<ChatRoom> _rooms = const [];
  bool _hasLoadedCache = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  RoomCursor? _next;
  AppFailure? _failure;
  String _query = '';
  RoomFilter _filter;
  final Map<String, ChatUser> _users = {};
  final Set<String> _requestedUsers = {};

  String get currentUserId => kit.currentUserId;

  /// Pinned first, then most recently updated.
  List<ChatRoom> get rooms => _rooms;

  /// False until the cache answered once; show a skeleton meanwhile.
  bool get hasLoadedCache => _hasLoadedCache;

  /// A refresh from the source is running.
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  /// The last refresh or paging failure, cleared by the next success.
  AppFailure? get failure => _failure;

  /// Unread messages over the rooms of this list, muted rooms excluded.
  int get totalUnread =>
      _rooms.fold(0, (sum, room) => room.muted ? sum : sum + room.unreadCount);

  String get query => _query;

  /// Which rooms this list shows. Applied to the cache, and passed to
  /// `ChatDataSource.fetchRooms` so the backend can filter too.
  RoomFilter get filter => _filter;

  /// Shows only rooms matching [filter] (for example tabs or chips), then
  /// refetches the first page.
  void setFilter(RoomFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _watch();
    notifyListeners();
    unawaited(refresh());
  }

  /// Peers of direct rooms and authors of last messages, resolved lazily.
  Map<String, ChatUser> get users => _users;

  Presence? presenceOf(String userId) => _repository.presence(userId);

  /// The other member of a direct room, once resolved.
  ChatUser? peerOf(ChatRoom room) {
    final id = room.otherUserId(currentUserId);
    return id == null ? null : _users[id];
  }

  /// Names of the members typing in [room] (unresolved users are skipped
  /// until their names arrive).
  List<String> typingNames(ChatRoom room) => [
    for (final id in _repository.typing(room.id).userIds)
      if (id != currentUserId) ?_users[id]?.name,
  ];

  /// Filters rooms by title or member name, after
  /// `ChatConfig.searchDebounce`.
  void search(String query) {
    final q = query.trim();
    if (q == _query) return;
    _searchTimer?.cancel();
    _searchTimer = Timer(kit.config.searchDebounce, () {
      _query = q;
      _watch();
      notifyListeners();
      unawaited(refresh());
    });
  }

  /// Fetches the first page of rooms (for the current search and filter).
  Future<void> refresh() async {
    final seq = ++_refreshSeq;
    _isLoading = true;
    _notify();
    try {
      await _fetchFirstPage(seq);
      if (seq == _refreshSeq) _failure = null;
    } on AppFailure catch (failure) {
      if (seq == _refreshSeq) _failure = failure;
    } on Object {
      // Disposed meanwhile: the kit (and its cache) may be closed.
      if (!_disposed) rethrow;
    } finally {
      if (seq == _refreshSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Fetches the next page of rooms. Ignored while loading or at the end.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    final seq = _refreshSeq;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _repository.fetchRooms(
        after: _next,
        search: _searchOrNull,
        filter: _filter,
      );
      // A refresh (new search or filter) started meanwhile: stale page.
      if (seq != _refreshSeq) return;
      _hasMore = page.hasMore;
      _next = page.next;
      _failure = null;
    } on AppFailure catch (failure) {
      if (seq == _refreshSeq) _failure = failure;
    } on Object {
      if (!_disposed) rethrow;
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  String? get _searchOrNull => _query.isEmpty ? null : _query;

  Future<void> _fetchFirstPage(int seq) async {
    final page = await _repository.fetchRooms(
      search: _searchOrNull,
      filter: _filter,
    );
    if (seq != _refreshSeq) return;
    _hasMore = page.hasMore;
    _next = page.next;
  }

  /// Called by `ChatRepository.resync` after a reconnect; failures reach
  /// the caller of `ChatKit.resync`.
  Future<void> _resync() async {
    final seq = _refreshSeq;
    await _fetchFirstPage(seq);
    if (seq == _refreshSeq) {
      _failure = null;
      _notify();
    }
  }

  /// Pins or unpins [roomId]. Reverted, with [failure] set, on rejection.
  Future<void> setPinned(String roomId, {required bool pinned}) =>
      _flags(roomId, pinned: pinned);

  /// Mutes or unmutes [roomId]. Reverted, with [failure] set, on rejection.
  Future<void> setMuted(String roomId, {required bool muted}) =>
      _flags(roomId, muted: muted);

  Future<void> _flags(String roomId, {bool? pinned, bool? muted}) async {
    try {
      await _repository.setRoomFlags(roomId, pinned: pinned, muted: muted);
    } on AppFailure catch (failure) {
      _failure = failure;
      _notify();
    }
  }

  void _watch() {
    unawaited(_roomsSub?.cancel());
    _roomsSub = _repository
        .watchRooms(search: _searchOrNull, filter: _filter)
        .listen(_onRooms);
  }

  void _onRooms(List<ChatRoom> rooms) {
    _rooms = rooms;
    _hasLoadedCache = true;
    _notify();
    final missing = <String>{};
    for (final room in rooms) {
      final peer = room.otherUserId(currentUserId);
      final author = room.lastMessage?.authorId;
      for (final id in [?peer, ?author]) {
        if (id != currentUserId && _requestedUsers.add(id)) missing.add(id);
      }
    }
    if (missing.isNotEmpty) unawaited(_resolve(missing));
  }

  Future<void> _resolve(Set<String> ids) async {
    final Map<String, ChatUser> found;
    try {
      found = await _repository.users(ids);
    } on Object {
      // Disposed meanwhile: the kit (and its cache) may be closed.
      if (_disposed) return;
      rethrow;
    }
    if (_disposed || found.isEmpty) return;
    _users.addAll(found);
    notifyListeners();
  }

  void _onPresence(Presence presence) {
    final isPeer = _rooms.any(
      (room) => room.otherUserId(currentUserId) == presence.userId,
    );
    if (isPeer) _notify();
  }

  void _onTyping(TypingState state) {
    if (!_rooms.any((room) => room.id == state.roomId)) return;
    final missing = {
      for (final id in state.userIds)
        if (id != currentUserId && _requestedUsers.add(id)) id,
    };
    if (missing.isNotEmpty) unawaited(_resolve(missing));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @visibleForTesting
  bool get hasPendingTimers => _searchTimer?.isActive ?? false;

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    unawaited(_roomsSub?.cancel());
    unawaited(_presenceSub?.cancel());
    unawaited(_typingSub?.cancel());
    if (kit.isOpen) unawaited(_repository.closeInbox(onResync: _resync));
    super.dispose();
  }
}
