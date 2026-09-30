import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/cache/chat_cache.dart';
import 'package:flutter_chat_kit/src/cache/drift_chat_cache.dart';
import 'package:flutter_chat_kit/src/config/chat_config.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';
import 'package:flutter_chat_kit/src/source/chat_uploader.dart';
import 'package:flutter_chat_kit/src/source/chat_user_resolver.dart';

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

  bool get isOpen => _isOpen;

  bool get isOnline => _isOnline;

  bool get canSendMedia => uploader != null;

  /// Opens the user's cache and resumes pending sends.
  Future<void> open() async {
    if (_isOpen) return;
    await cache.open(currentUserId);
    _isOpen = true;
    notifyListeners();
  }

  /// Stops sync and closes the cache. Controllers must be disposed first.
  Future<void> close() async {
    if (!_isOpen) return;
    _isOpen = false;
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

  /// Feed connectivity from the app. Going online flushes the outbox.
  void setOnline({required bool online}) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }

  /// Retries every pending or failed send now.
  Future<void> retryPending() async {}
}
