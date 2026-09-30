import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/controllers/chat_kit.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/models/room_member.dart';
import 'package:flutter_chat_kit/src/models/typing.dart';
import 'package:flutter_chat_kit/src/sync/chat_repository.dart';
import 'package:flutter_chat_kit/src/sync/outbox.dart';
import 'package:flutter_chat_kit/src/sync/room_window.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
import 'package:uuid/uuid.dart';

/// State of one open room: the visible messages (newest first), paging,
/// jumps, receipts, typing, selection, and every write the user makes.
///
/// Cached messages show at once; the room then syncs in the background.
/// The message list reports its viewport through [onViewportChanged];
/// the controller never scrolls. Create with `ChatKit.room(id)` and
/// dispose before `ChatKit.close()`.
class ChatRoomController extends ChangeNotifier {
  ChatRoomController(this.kit, this.roomId)
    : _repository = kit.repository,
      _outbox = kit.outbox {
    _roomSub = _repository.watchRoom(roomId).listen(_onRoom);
    _typingSub = _repository.watchTyping(roomId).listen(_onTyping);
    _errorSub = _outbox.errors
        .where((e) => e.entry.roomId == roomId)
        .listen(_onOutboxError);
    _typingIds = _typingOf(_repository.typing(roomId));
    ready = _open();
  }

  final ChatKit kit;
  final String roomId;
  final ChatRepository _repository;
  final Outbox _outbox;

  static const _uuid = Uuid();

  /// Completes when cached messages are shown and the first sync ended
  /// (successfully or with [failure] set).
  late final Future<void> ready;

  StreamSubscription<ChatRoom?>? _roomSub;
  StreamSubscription<List<Message>>? _messagesSub;
  StreamSubscription<TypingState>? _typingSub;
  StreamSubscription<OutboxError>? _errorSub;
  Timer? _highlightTimer;
  bool _disposed = false;
  bool _opened = false;

  RoomWindow _window = const LatestWindow();
  RoomWindow? _windowOfMessages;
  int _userMoves = 0;
  List<Message> _messages = const [];
  bool _hasMessages = false;
  ChatRoom? _room;
  List<String> _typingIds = const [];
  final Map<String, ChatUser> _users = {};
  final Set<String> _requestedUsers = {};
  final Map<String, Message?> _outside = {};
  final Set<String> _selected = {};

  bool _isSyncing = true;
  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;
  bool _isJumping = false;
  AppFailure? _failure;

  bool _atBottom = true;
  bool _readCaptured = false;
  DateTime? _readAtOpen;
  MessageCursor? _markedUpTo;

  final _highlighted = ValueNotifier<String?>(null);
  final _newMessages = ValueNotifier<int>(0);

  String get currentUserId => kit.currentUserId;

  ChatRoom? get room => _room;

  List<RoomMember> get members => _room?.members ?? const [];

  /// Visible messages, newest first (index 0 is the bottom of the list).
  List<Message> get messages => _messages;

  /// False until the cache answered once; show a skeleton meanwhile.
  bool get hasLoadedCache => _hasMessages;

  /// Authors and members, resolved lazily through `ChatUserResolver`.
  Map<String, ChatUser> get users => _users;

  bool get isSyncing => _isSyncing;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get isLoadingNewer => _isLoadingNewer;
  bool get isJumping => _isJumping;
  bool get hasMoreOlder => _window.hasMoreOlder;
  bool get hasMoreNewer => _window.hasMoreNewer;

  /// Showing an older slice after a jump; the newest messages are not in
  /// [messages]. Offer "back to latest".
  bool get isDetached => _window is DetachedWindow;

  /// The last failure (sync, paging, jump, or a rejected edit, delete or
  /// reaction), cleared by the next success.
  AppFailure? get failure => _failure;

  /// Local id of the message to highlight after a jump; cleared after
  /// `ChatConfig.highlightDuration`.
  ValueListenable<String?> get highlightedId => _highlighted;

  /// Messages from others that arrived while the list was not at the
  /// bottom. Reset when it gets there.
  ValueListenable<int> get newMessagesCount => _newMessages;

  bool get isAtBottom => _atBottom;

  /// The oldest message from others that was unread when the room opened;
  /// the list draws the "new messages" divider above it.
  MessageCursor? get unreadDividerCursor {
    final readAt = _readAtOpen;
    if (readAt == null) return null;
    Message? oldest;
    for (final m in _messages) {
      if (!m.createdAt.isAfter(readAt)) break;
      if (m.authorId != currentUserId && !m.status.isLocal) oldest = m;
    }
    return oldest?.cursor;
  }

  /// Ids of members typing now (never the current user).
  List<String> get typingUserIds => _typingIds;

  Set<String> get selectedIds => Set.unmodifiable(_selected);

  // ------------------------------------------------------------ receipts

  /// Members who read [message], its author excluded.
  List<RoomMember> seenBy(Message message) => [
    for (final m in members)
      if (m.userId != message.authorId && m.hasRead(message)) m,
  ];

  /// The status to show on the current user's message: `seen` once every
  /// other member read it, `delivered` once every other member received
  /// it, else the stored status.
  MessageStatus effectiveStatus(Message message) {
    final status = message.status;
    if (message.authorId != currentUserId || status.isLocal) return status;
    final others = [
      for (final m in members)
        if (m.userId != currentUserId) m,
    ];
    if (others.isEmpty || status == MessageStatus.seen) return status;
    if (others.every((m) => m.hasRead(message))) return MessageStatus.seen;
    if (status == MessageStatus.delivered ||
        others.every((m) => m.hasReceived(message))) {
      return MessageStatus.delivered;
    }
    return status;
  }

  /// A message by id or local id: from [messages], else from the cache
  /// (loaded in the background; listeners are notified when it arrives).
  /// Used for reply previews.
  Message? messageById(String id) {
    final visible = _find(id);
    if (visible != null) return visible;
    if (_outside.containsKey(id)) return _outside[id];
    _outside[id] = null;
    _background(kit.cache.messageByAnyId(id), (m) {
      if (m == null) return;
      _outside[id] = m;
      notifyListeners();
    });
    return null;
  }

  // -------------------------------------------------------------- paging

  /// Loads one more page of older messages. Ignored while loading or at the
  /// start of history.
  Future<void> loadOlder() async {
    if (_isLoadingOlder || !_window.hasMoreOlder) return;
    final base = _window;
    _isLoadingOlder = true;
    _notify();
    try {
      final next = await _repository.loadOlder(roomId, base);
      if (_disposed || !identical(_window, base)) return;
      _userMoves++;
      await _setWindow(next);
      _failure = null;
    } on AppFailure catch (failure) {
      _failure = failure;
    } finally {
      _isLoadingOlder = false;
      _notify();
    }
  }

  /// Loads newer messages of a detached slice; it becomes the latest window
  /// once it reaches the newest messages.
  Future<void> loadNewer() async {
    if (_isLoadingNewer || _window is! DetachedWindow) return;
    final base = _window;
    _isLoadingNewer = true;
    _notify();
    try {
      final next = await _repository.loadNewer(roomId, base);
      if (_disposed || !identical(_window, base)) return;
      _userMoves++;
      await _setWindow(next);
      _failure = null;
    } on AppFailure catch (failure) {
      _failure = failure;
    } finally {
      _isLoadingNewer = false;
      _notify();
    }
  }

  /// Leaves a detached slice for the newest messages.
  Future<void> returnToLatest() async {
    _userMoves++;
    final latest = await _repository.latestWindow(roomId);
    if (_disposed) return;
    await _setWindow(latest);
    _newMessages.value = 0;
    _notify();
  }

  /// Makes [id] visible, loading its slice when needed, and highlights it.
  /// Returns its index in [messages], or null when it can't be found.
  Future<int?> jumpToMessage(String id) async {
    final index = _indexOf(id);
    if (index != null) {
      _highlight(_messages[index].localId);
      return index;
    }
    _isJumping = true;
    _notify();
    try {
      _userMoves++;
      final next = await _repository.jumpTo(roomId, id, current: _window);
      if (next == null || _disposed) return null;
      await _setWindow(next);
      final found = _indexOf(id);
      if (found != null) _highlight(_messages[found].localId);
      _failure = null;
      return found;
    } on AppFailure catch (failure) {
      _failure = failure;
      return null;
    } finally {
      _isJumping = false;
      _notify();
    }
  }

  /// Called by the message list when it reaches or leaves the bottom.
  void onViewportChanged({required bool atBottom}) {
    if (_atBottom == atBottom) return;
    _atBottom = atBottom;
    if (atBottom) {
      _newMessages.value = 0;
      _maybeMarkRead();
    }
    _notify();
  }

  // --------------------------------------------------------------- writes

  Future<void> sendText(String text, {String? replyToId}) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final id = _newId();
    await _send(
      TextMessage(
        id: id,
        localId: id,
        roomId: roomId,
        authorId: currentUserId,
        createdAt: kit.clock(),
        text: body,
        replyToId: replyToId,
      ),
    );
  }

  /// Sends [files]: all images in one message, one message per video,
  /// audio or file. [caption] goes on the first image or video message, or
  /// follows as a text. Throws `ValidationFailure({'attachments':
  /// 'too_large'})` when a file exceeds `ChatConfig.maxAttachmentBytes`.
  Future<void> sendMedia(
    List<Attachment> files, {
    String? caption,
    String? replyToId,
  }) async {
    if (files.isEmpty) return;
    final limit = kit.config.maxAttachmentBytes;
    if (limit != null && files.any((f) => (f.size ?? 0) > limit)) {
      throw const ValidationFailure({'attachments': 'too_large'});
    }
    final text = caption?.trim();
    var pendingCaption = text == null || text.isEmpty ? null : text;
    var reply = replyToId;
    final out = <Message>[];

    Message build(Message Function(String id, String? reply) create) {
      final id = _newId();
      final message = create(id, reply);
      reply = null;
      return message;
    }

    final images = [
      for (final f in files)
        if (f.kind == AttachmentKind.image) f,
    ];
    if (images.isNotEmpty) {
      final caption = pendingCaption;
      pendingCaption = null;
      out.add(
        build(
          (id, reply) => ImageMessage(
            id: id,
            localId: id,
            roomId: roomId,
            authorId: currentUserId,
            createdAt: kit.clock(),
            images: images,
            caption: caption,
            replyToId: reply,
          ),
        ),
      );
    }
    for (final f in files) {
      switch (f.kind) {
        case AttachmentKind.image:
          break;
        case AttachmentKind.video:
          final caption = pendingCaption;
          pendingCaption = null;
          out.add(
            build(
              (id, reply) => VideoMessage(
                id: id,
                localId: id,
                roomId: roomId,
                authorId: currentUserId,
                createdAt: kit.clock(),
                video: f,
                caption: caption,
                replyToId: reply,
              ),
            ),
          );
        case AttachmentKind.audio:
          out.add(
            build(
              (id, reply) => AudioMessage(
                id: id,
                localId: id,
                roomId: roomId,
                authorId: currentUserId,
                createdAt: kit.clock(),
                audio: f,
                duration: f.duration ?? Duration.zero,
                replyToId: reply,
              ),
            ),
          );
        case AttachmentKind.file:
          out.add(
            build(
              (id, reply) => FileMessage(
                id: id,
                localId: id,
                roomId: roomId,
                authorId: currentUserId,
                createdAt: kit.clock(),
                file: f,
                replyToId: reply,
              ),
            ),
          );
      }
    }
    for (final message in out) {
      await _send(message);
    }
    final rest = pendingCaption;
    if (rest != null) await sendText(rest, replyToId: reply);
  }

  Future<void> sendVoice(
    Attachment audio,
    Duration duration,
    List<double> waveform, {
    String? replyToId,
  }) async {
    final id = _newId();
    await _send(
      AudioMessage(
        id: id,
        localId: id,
        roomId: roomId,
        authorId: currentUserId,
        createdAt: kit.clock(),
        audio: audio,
        duration: duration,
        waveform: waveform,
        replyToId: replyToId,
      ),
    );
  }

  /// Sends an app-defined message, rendered by
  /// `ChatBuilders.customBuilders[customType]`.
  Future<void> sendCustom(
    String customType,
    Map<String, Object?> data, {
    String? replyToId,
    Map<String, Object?> metadata = const {},
  }) async {
    final id = _newId();
    await _send(
      CustomMessage(
        id: id,
        localId: id,
        roomId: roomId,
        authorId: currentUserId,
        createdAt: kit.clock(),
        customType: customType,
        data: data,
        replyToId: replyToId,
        metadata: metadata,
      ),
    );
  }

  /// Replaces the text (or the caption of an image or video message).
  Future<void> edit(String id, String newText) async {
    final message = _find(id) ?? await kit.cache.messageByAnyId(id);
    final body = newText.trim();
    if (message == null || body.isEmpty) return;
    final edited = switch (message) {
      TextMessage() => message.copyWith(text: body),
      ImageMessage() => message.copyWith(caption: body),
      VideoMessage() => message.copyWith(caption: body),
      _ => null,
    };
    if (edited == null || edited == message) return;
    await _outbox.edit(edited);
  }

  Future<void> delete(String id) async {
    _selected.remove(id);
    await _outbox.delete(roomId, id);
  }

  /// Toggles the current user's [emoji] reaction on the message.
  Future<void> react(String id, String emoji) async {
    final message = _find(id) ?? await kit.cache.messageByAnyId(id);
    if (message == null) return;
    final mine = message.reactions[emoji]?.contains(currentUserId) ?? false;
    await _outbox.react(roomId, id, emoji, add: !mine);
  }

  Future<void> retry(String localId) => _outbox.retry(localId);

  Future<bool> discard(String localId) => _outbox.discard(localId);

  ValueListenable<double?> progressOf(String localId) =>
      _outbox.progressOf(localId);

  // ------------------------------------------------------------ selection

  /// Selects or unselects a message by local id.
  void toggleSelect(String localId) {
    if (!_selected.remove(localId)) _selected.add(localId);
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
  }

  // ------------------------------------------------------------ internals

  Future<void> _open() async {
    try {
      final room = await _repository.watchRoom(roomId).first;
      final me = room?.member(currentUserId);
      if (me != null) {
        _readAtOpen = me.lastReadAt ?? DateTime.utc(1970);
      }
      _readCaptured = true;
      final cached = await _repository.latestWindow(roomId);
      if (_disposed) return;
      final moves = _userMoves;
      await _setWindow(cached);
      if (_disposed) return;
      _opened = true;
      final synced = await _repository.openRoom(roomId);
      if (_disposed) return;
      if (_userMoves == moves) await _setWindow(synced);
      _failure = null;
    } on AppFailure catch (failure) {
      _failure = failure;
    } on Object {
      // Disposed while opening: the kit may have closed its streams.
      if (!_disposed) rethrow;
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  Future<void> _setWindow(RoomWindow window) {
    _window = window;
    unawaited(_messagesSub?.cancel());
    final first = Completer<void>();
    _messagesSub = _repository
        .watchMessages(roomId, window)
        .listen(
          (messages) {
            _onMessages(messages, window);
            if (!first.isCompleted) first.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!first.isCompleted) first.completeError(error, stack);
          },
        );
    return first.future;
  }

  void _onMessages(List<Message> messages, RoomWindow window) {
    final previous = _messages;
    final sameWindow = identical(_windowOfMessages, window);
    _messages = messages;
    _windowOfMessages = window;
    _hasMessages = true;

    if (sameWindow && !_atBottom && previous.isNotEmpty) {
      final newest = previous.first.cursor;
      var arrived = 0;
      for (final m in messages) {
        if (!m.cursor.isAfter(newest)) break;
        if (m.authorId != currentUserId && !m.status.isLocal) arrived++;
      }
      if (arrived > 0) _newMessages.value += arrived;
    }

    _resolveUsers([
      for (final m in messages) ...[
        m.authorId,
        if (m.authorId == currentUserId) ?m.sentBy,
      ],
    ]);
    _maybeMarkRead();
    _notify();
  }

  void _onRoom(ChatRoom? room) {
    _room = room;
    if (room != null) _resolveUsers(room.members.map((m) => m.userId));
    _notify();
  }

  void _onTyping(TypingState state) {
    _typingIds = _typingOf(state);
    _resolveUsers(_typingIds);
    _notify();
  }

  List<String> _typingOf(TypingState state) => [
    for (final id in state.userIds)
      if (id != currentUserId) id,
  ];

  void _onOutboxError(OutboxError error) {
    _failure = error.failure;
    _notify();
  }

  void _maybeMarkRead() {
    if (!_atBottom ||
        !_readCaptured ||
        !kit.config.markReadWhenAtBottom ||
        _window is! LatestWindow) {
      return;
    }
    final newest = _messages.firstWhereOrNull(
      (m) => m.authorId != currentUserId && !m.status.isLocal,
    );
    if (newest == null) return;
    final cursor = newest.cursor;
    final readAt = _room?.member(currentUserId)?.lastReadAt;
    if (readAt != null && !cursor.createdAt.isAfter(readAt)) return;
    final marked = _markedUpTo;
    if (marked != null && !cursor.isAfter(marked)) return;
    _markedUpTo = cursor;
    unawaited(
      _repository
          .markRead(roomId, cursor)
          .then<void>(
            (_) {},
            onError: (Object _) {
              // Retried when the list reaches the bottom again.
              if (_markedUpTo == cursor) _markedUpTo = null;
            },
          ),
    );
  }

  void _resolveUsers(Iterable<String> ids) {
    final missing = <String>{
      for (final id in ids)
        if (id != currentUserId && _requestedUsers.add(id)) id,
    };
    if (missing.isEmpty) return;
    _background(_repository.users(missing), (found) {
      if (found.isEmpty) return;
      _users.addAll(found);
      notifyListeners();
    });
  }

  /// Runs [work] without awaiting it. Once disposed, results and errors are
  /// dropped: the kit (and its cache) may already be closed.
  void _background<T>(Future<T> work, void Function(T value) onValue) {
    unawaited(
      work.then<void>(
        (value) {
          if (!_disposed) onValue(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!_disposed) Error.throwWithStackTrace(error, stack);
        },
      ),
    );
  }

  Future<void> _send(Message message) async {
    if (_window is DetachedWindow) await returnToLatest();
    final agentId = kit.agentId;
    await _outbox.send(
      agentId == null || message.sentBy != null
          ? message
          : message.copyWith(sentBy: agentId),
    );
  }

  void _highlight(String localId) {
    _highlightTimer?.cancel();
    _highlighted.value = localId;
    _highlightTimer = Timer(kit.config.highlightDuration, () {
      if (!_disposed) _highlighted.value = null;
    });
  }

  Message? _find(String id) => _messages.firstWhereOrNull((m) => m.matches(id));

  int? _indexOf(String id) {
    final i = _messages.indexWhere((m) => m.matches(id));
    return i < 0 ? null : i;
  }

  String _newId() => _uuid.v4();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @visibleForTesting
  bool get hasPendingTimers => _highlightTimer?.isActive ?? false;

  @override
  void dispose() {
    _disposed = true;
    _highlightTimer?.cancel();
    unawaited(_roomSub?.cancel());
    unawaited(_messagesSub?.cancel());
    unawaited(_typingSub?.cancel());
    unawaited(_errorSub?.cancel());
    if (_opened) unawaited(_repository.closeRoom(roomId));
    _highlighted.dispose();
    _newMessages.dispose();
    super.dispose();
  }
}
