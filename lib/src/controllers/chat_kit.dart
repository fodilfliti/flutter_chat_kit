import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/cache/chat_cache.dart';
import 'package:flutter_chat_kit/src/cache/drift_chat_cache.dart';
import 'package:flutter_chat_kit/src/config/chat_config.dart';
import 'package:flutter_chat_kit/src/controllers/audio_player_hub.dart';
import 'package:flutter_chat_kit/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_kit/src/controllers/inbox_controller.dart';
import 'package:flutter_chat_kit/src/media/chat_media_store.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/room_filter.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';
import 'package:flutter_chat_kit/src/source/chat_uploader.dart';
import 'package:flutter_chat_kit/src/source/chat_user_resolver.dart';
import 'package:flutter_chat_kit/src/sync/chat_repository.dart';
import 'package:flutter_chat_kit/src/sync/outbox.dart';
import 'package:flutter_chat_kit/src/sync/retry_policy.dart';

/// The root object of the kit. Create one per signed-in user.
///
/// It owns the local database (one file per user), the sync and the outbox,
/// and creates screen controllers. Provide it to widgets with
/// `ChatKitScope`.
///
/// ```dart
/// final kit = ChatKit(currentUserId: uid, source: MyChatSource());
/// await kit.open();
/// // ...
/// await kit.clearUserData(); // on sign-out
/// ```
class ChatKit extends ChangeNotifier {
  /// A kit for [currentUserId] talking to [source]. Nothing runs until
  /// [open].
  ///
  /// Optional parts: [uploader] enables media and voice, [users] resolves
  /// missing names and avatars, [agentId] is for shared business profiles.
  /// [cache] defaults to a `DriftChatCache` (SQLite), [onSaveMedia] handles
  /// the media viewer's "Save" action, [mediaStore] replaces the media
  /// store and [audio] shares an `AudioPlayerHub` (the kit creates and
  /// disposes its own otherwise).
  ChatKit({
    required this.currentUserId,
    required this.source,
    this.agentId,
    this.uploader,
    this.users,
    this.config = const ChatConfig(),
    this.retryPolicy = const RetryPolicy(),
    this.clock = _utcNow,
    ChatCache? cache,
    SaveMediaCallback? onSaveMedia,
    ChatMediaStore Function(ChatKit kit)? mediaStore,
    AudioPlayerHub? audio,
  }) : cache = cache ?? DriftChatCache(),
       audio = audio ?? AudioPlayerHub(),
       _ownsAudio = audio == null {
    media =
        mediaStore?.call(this) ??
        ChatMediaStore(
          userId: currentUserId,
          cache: this.cache,
          clock: clock,
          maxBytes: config.maxMediaCacheBytes,
          onSave: onSaveMedia,
        );
  }

  /// The profile the kit chats as: rooms, messages and the local database
  /// belong to it.
  final String currentUserId;

  /// The app's backend: where rooms and messages are read, written and
  /// listened to. See doc/adapters/your_api.md.
  final ChatSource source;

  /// The person acting for [currentUserId] when a business profile is
  /// shared by several staff members (usually their account id). Stamped on
  /// every sent message as `Message.sentBy`, so colleagues see who answered.
  /// Null for personal profiles.
  final String? agentId;

  /// Null disables media and voice sending.
  final ChatUploader? uploader;

  /// Looks up names and avatars the backend did not send with its pages
  /// (`ChatPage.users`) or events (`UsersChanged`).
  final ChatUserResolver? users;

  /// Behaviour settings: page sizes, grouping, reactions, typing, caches.
  final ChatConfig config;

  /// Backoff of the outbox.
  final RetryPolicy retryPolicy;

  /// Time source (UTC) for new messages, sync and retries. Tests replace it.
  final DateTime Function() clock;

  /// The local store. Only the kit writes to it; widgets read through
  /// controllers.
  final ChatCache cache;

  /// Media files on disk (D11): downloads each file once, keeps the user's
  /// own uploads, exports with "Save".
  late final ChatMediaStore media;

  /// Plays one voice message at a time.
  final AudioPlayerHub audio;
  final bool _ownsAudio;

  bool _isOpen = false;
  bool _isOnline = true;
  ChatRepository? _repository;
  Outbox? _outbox;

  /// Whether [open] completed and [close] was not called since. Controllers
  /// can only be created while open.
  bool get isOpen => _isOpen;

  /// The last value given to [setOnline]; true by default. While false,
  /// sends wait in the outbox.
  bool get isOnline => _isOnline;

  /// Whether an [uploader] was given; the composer shows the attachment
  /// and mic buttons only then.
  bool get canSendMedia => uploader != null;

  /// Sync between the source and the cache. Available while open.
  ChatRepository get repository =>
      _repository ?? (throw StateError('ChatKit is not open'));

  /// The write queue (send, edit, delete, react). Available while open.
  Outbox get outbox => _outbox ?? (throw StateError('ChatKit is not open'));

  /// A new inbox controller showing rooms that match [filter]. Create one
  /// per list (for example a "Chats" and a "Groups" tab). The caller
  /// disposes it.
  InboxController inbox({RoomFilter filter = RoomFilter.all}) =>
      InboxController(this, filter: filter);

  /// A new controller for [roomId]. The caller disposes it (before
  /// [close]).
  ChatRoomController room(String roomId) => ChatRoomController(this, roomId);

  /// Opens the user's cache and resumes pending sends.
  Future<void> open() async {
    if (_isOpen) return;
    await cache.open(currentUserId);
    _repository = ChatRepository(
      currentUserId: currentUserId,
      source: source,
      cache: cache,
      users: users,
      config: config,
      clock: clock,
    );
    final outbox = _outbox = Outbox(
      currentUserId: currentUserId,
      source: source,
      cache: cache,
      uploader: uploader,
      retryPolicy: retryPolicy,
      clock: clock,
      onUploaded: (local, remoteUrl) =>
          media.adopt(local.localPath!, remoteUrl, mimeType: local.mimeType),
    )..setOnline(online: _isOnline);
    _isOpen = true;
    unawaited(outbox.flush());
    notifyListeners();
  }

  /// Stops sync and closes the cache. Controllers must be disposed first.
  Future<void> close() async {
    if (!_isOpen) return;
    _isOpen = false;
    final repository = _repository;
    final outbox = _outbox;
    _repository = null;
    _outbox = null;
    await outbox?.dispose();
    await repository?.dispose();
    await audio.stop();
    media.close();
    await cache.close();
    notifyListeners();
  }

  /// Deletes this user's cached rooms, messages, drafts, pending sends and
  /// stored media files.
  Future<void> clearUserData() async {
    if (_isOpen) {
      await media.clear();
      await cache.clear();
      return;
    }
    await cache.open(currentUserId);
    try {
      await media.clear();
      await cache.clear();
    } finally {
      await cache.close();
    }
  }

  /// Feed connectivity from the app. Going online fills the gaps of open
  /// rooms and flushes the outbox.
  void setOnline({required bool online}) {
    if (_isOnline == online) return;
    _isOnline = online;
    _outbox?.setOnline(online: online);
    final repository = _repository;
    if (repository != null) {
      if (online) {
        // A failed resync leaves rooms unsynced; the next reconnect or room
        // open retries, and controllers report their own failures.
        unawaited(repository.resync().then((_) {}, onError: (Object _) {}));
      } else {
        repository.connectionLost();
      }
    }
    notifyListeners();
  }

  /// Stores names and avatars the app got elsewhere (a profile screen, a
  /// push, its own user cache). Open chat screens update at once; ignored
  /// while closed.
  Future<void> updateUsers(List<ChatUser> users) async {
    await _repository?.putUsers(users);
  }

  /// Retries every pending or failed send now.
  Future<void> retryPending() async {
    await _outbox?.retryAll();
  }

  /// Releases the audio player the kit created. [close] first.
  @override
  void dispose() {
    if (_ownsAudio) audio.dispose();
    super.dispose();
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
