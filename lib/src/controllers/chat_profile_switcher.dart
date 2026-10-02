import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_chat_kit/src/controllers/chat_kit.dart';
import 'package:flutter_chat_kit/src/models/chat_profile.dart';

/// Builds the kit of one profile. Return a new kit on every call: the
/// switcher opens, closes and disposes it.
typedef ChatKitFactory = ChatKit Function(ChatProfile profile);

/// Lets one signed-in account chat as several profiles (personal, business
/// pages, ...), one at a time.
///
/// Only the active profile has an open [ChatKit]: its own local database,
/// media folder and realtime connection. Switching opens the new profile's
/// kit, swaps it in, then closes the old one. Provide it to widgets with
/// `ChatProfileScope`, which rebuilds the chat screens on every switch.
///
/// ```dart
/// final switcher = ChatProfileSwitcher(
///   profiles: [
///     ChatProfile(id: uid, name: 'Ali'),
///     ChatProfile(
///       id: shopId,
///       name: 'Lemsa Shop',
///       kind: ChatProfileKind.business,
///       agentId: uid,
///     ),
///   ],
///   createKit: (profile) => ChatKit(
///     currentUserId: profile.id,
///     agentId: profile.agentId,
///     source: MyChatSource(actingAs: profile.id),
///   ),
/// );
/// await switcher.open();
/// await switcher.switchTo(shopId);
/// await switcher.clearAllUserData(); // on sign-out
/// ```
///
/// See doc/adapters/profiles.md.
class ChatProfileSwitcher extends ChangeNotifier {
  /// A switcher over [profiles] (not empty, unique ids) starting at
  /// [initialProfileId], or the first profile when null. Throws an
  /// [ArgumentError] for an empty list, duplicate ids or an unknown
  /// initial id. Nothing opens until [open].
  ChatProfileSwitcher({
    required List<ChatProfile> profiles,
    required this.createKit,
    String? initialProfileId,
  }) : _profiles = _checked(profiles),
       _active = initialProfileId == null
           ? profiles.first
           : profiles.where((p) => p.id == initialProfileId).firstOrNull ??
                 (throw ArgumentError.value(
                   initialProfileId,
                   'initialProfileId',
                   'is not one of the profiles',
                 ));

  /// Builds the kit of a profile when it becomes active, and a short-lived
  /// one to clear a profile's data.
  final ChatKitFactory createKit;

  List<ChatProfile> _profiles;
  ChatProfile _active;
  ChatKit? _kit;
  bool _isSwitching = false;
  bool _isOnline = true;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  /// Every profile of the account, in menu order.
  List<ChatProfile> get profiles => _profiles;

  /// The profile the user chats as.
  ChatProfile get active => _active;

  /// The open kit of [active]. Null before [open] and after [close].
  ChatKit? get kit => _kit;

  /// Whether the active profile's kit is open, so chat screens can show.
  bool get isOpen => _kit != null;

  /// True while [switchTo] opens the next profile's kit.
  bool get isSwitching => _isSwitching;

  /// The last value given to [setOnline]; true by default.
  bool get isOnline => _isOnline;

  /// The profile with [id], or null when it is not in [profiles].
  ChatProfile? profileById(String id) =>
      _profiles.where((p) => p.id == id).firstOrNull;

  /// Opens the active profile's kit.
  Future<void> open() => _serial(() async {
    if (_kit != null) return;
    _kit = await _start(active);
    _notify();
  });

  /// Makes [profileId] the active profile. While open, its kit is opened
  /// before the old one is closed; if opening fails, the old profile stays
  /// active and the error is rethrown.
  Future<void> switchTo(String profileId) => _serial(() async {
    final target =
        profileById(profileId) ??
        (throw ArgumentError.value(profileId, 'profileId', 'unknown profile'));
    await _activate(target);
  });

  /// Replaces the profile list, for example after the account joined or left
  /// a business, or with fresh unread counts. If the active profile is gone,
  /// the first profile becomes active. With [clearRemoved], the cached data
  /// of removed profiles is deleted from the device.
  Future<void> setProfiles(
    List<ChatProfile> profiles, {
    bool clearRemoved = true,
  }) => _serial(() async {
    final next = _checked(profiles);
    final removed = [
      for (final p in _profiles)
        if (!next.any((n) => n.id == p.id)) p,
    ];
    _profiles = next;
    final current = profileById(_active.id);
    if (current == null) {
      await _activate(next.first);
    } else {
      _active = current;
      _notify();
    }
    if (clearRemoved) {
      for (final p in removed) {
        await _clear(p);
      }
    }
  });

  /// Feeds connectivity to the active kit, and to kits opened later.
  void setOnline({required bool online}) {
    if (_isOnline == online) return;
    _isOnline = online;
    _kit?.setOnline(online: online);
    _notify();
  }

  /// Closes the active kit. Chat screens under `ChatProfileScope` are
  /// removed first.
  Future<void> close() => _serial(_closeActive);

  /// Closes the active kit and deletes the cached data of every profile
  /// (rooms, messages, pending sends, media). Call it on sign-out.
  Future<void> clearAllUserData() => _serial(() async {
    await _closeActive();
    for (final p in _profiles) {
      await _clear(p);
    }
  });

  @override
  void dispose() {
    _disposed = true;
    final kit = _kit;
    _kit = null;
    if (kit != null) unawaited(_retire(kit));
    super.dispose();
  }

  Future<void> _activate(ChatProfile target) async {
    final old = _kit;
    if (old == null) {
      _active = target;
      _notify();
      return;
    }
    if (target.id == _active.id) return;
    _isSwitching = true;
    _notify();
    final ChatKit next;
    try {
      next = await _start(target);
    } finally {
      _isSwitching = false;
    }
    _kit = next;
    _active = target;
    _notify();
    await _nextFrame();
    await _retire(old);
  }

  Future<void> _closeActive() async {
    final kit = _kit;
    if (kit == null) return;
    _kit = null;
    _notify();
    await _nextFrame();
    await _retire(kit);
  }

  Future<ChatKit> _start(ChatProfile profile) async {
    final kit = createKit(profile)..setOnline(online: _isOnline);
    try {
      await kit.open();
    } on Object {
      kit.dispose();
      rethrow;
    }
    return kit;
  }

  Future<void> _retire(ChatKit kit) async {
    try {
      await kit.close();
    } finally {
      kit.dispose();
    }
  }

  Future<void> _clear(ChatProfile profile) async {
    final kit = createKit(profile);
    try {
      await kit.clearUserData();
    } finally {
      kit.dispose();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Lets the widget tree drop the old kit (and dispose its controllers)
  /// before it closes. Bounded, since no frame comes while the app is in the
  /// background.
  static Future<void> _nextFrame() {
    final scheduler = SchedulerBinding.instance;
    if (!scheduler.hasScheduledFrame) {
      return Future<void>.delayed(Duration.zero);
    }
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final timeout = Timer(const Duration(seconds: 1), finish);
    unawaited(
      scheduler.endOfFrame.then((_) {
        timeout.cancel();
        finish();
      }),
    );
    return done.future;
  }

  static List<ChatProfile> _checked(List<ChatProfile> profiles) {
    if (profiles.isEmpty) {
      throw ArgumentError.value(profiles, 'profiles', 'must not be empty');
    }
    final ids = {for (final p in profiles) p.id};
    if (ids.length != profiles.length) {
      throw ArgumentError.value(profiles, 'profiles', 'has duplicate ids');
    }
    return List.unmodifiable(profiles);
  }
}
