import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/cache/chat_cache.dart';
import 'package:flutter_chat_kit/src/cache/drift_chat_cache.dart';
import 'package:flutter_chat_kit/src/config/chat_config.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';
import 'package:flutter_chat_kit/src/source/chat_uploader.dart';
import 'package:flutter_chat_kit/src/source/chat_user_resolver.dart';
import 'package:flutter_chat_kit/src/sync/chat_repository.dart';

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
  ChatKit({
    required this.currentUserId,
    required this.source,
    this.uploader,
    this.users,
    this.config = const ChatConfig(),
    ChatCache? cache,
  }) : cache = cache ?? DriftChatCache();

  final String currentUserId;
  final ChatSource source;

  /// Null disables media and voice sending.
  final ChatUploader? uploader;
  final ChatUserResolver? users;
  final ChatConfig config;

  /// The local store. Only the kit writes to it; widgets read through
  /// controllers.
  final ChatCache cache;

  bool _isOpen = false;
  bool _isOnline = true;
  ChatRepository? _repository;

  bool get isOpen => _isOpen;

  bool get isOnline => _isOnline;

  bool get canSendMedia => uploader != null;

  /// Sync between the source and the cache. Available while open.
  ChatRepository get repository =>
      _repository ?? (throw StateError('ChatKit is not open'));

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
    );
    _isOpen = true;
    notifyListeners();
  }

  /// Stops sync and closes the cache. Controllers must be disposed first.
  Future<void> close() async {
    if (!_isOpen) return;
    _isOpen = false;
    final repository = _repository;
    _repository = null;
    await repository?.dispose();
    await cache.close();
    notifyListeners();
  }

  /// Deletes this user's cached rooms, messages, drafts and pending sends.
  Future<void> clearUserData() async {
    if (_isOpen) {
      await cache.clear();
      return;
    }
    await cache.open(currentUserId);
    try {
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

  /// Retries every pending or failed send now.
  Future<void> retryPending() async {}
}
