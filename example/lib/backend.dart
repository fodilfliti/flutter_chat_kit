import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/fake/fake_chat_source.dart';
import 'package:flutter_chat_kit_example/fake/fake_uploader.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';

/// The fake backend of one signed-in account, which chats as two profiles:
/// its personal profile and "Lemsa Shop", a business it answers for along
/// with other staff. Only the active profile's kit is open.
class ExampleBackend {
  /// `cache` builds the local store of each kit; tests pass in-memory ones.
  ExampleBackend({this._cache}) {
    switcher = ChatProfileSwitcher(profiles: profiles, createKit: _createKit);
    liveMessages.addListener(() {
      for (final source in _sources.values) {
        source.liveMessages = liveMessages.value;
      }
    });
  }

  static const profiles = [
    ChatProfile(id: FakeChatSource.personalId, name: 'Ali'),
    ChatProfile(
      id: FakeChatSource.shopId,
      name: 'Lemsa Shop',
      avatarUrl: 'https://picsum.photos/seed/lemsa-shop/150',
      kind: ChatProfileKind.business,
      // You answer for the shop as yourself: colleagues see your name.
      agentId: FakeChatSource.personalId,
      unreadCount: 1,
    ),
  ];

  final ChatCache Function()? _cache;
  late final ChatProfileSwitcher switcher;

  /// One fake server per profile, kept across switches.
  final Map<String, FakeChatSource> _sources = {};
  bool _online = true;

  /// When on, people write to every profile on their own, as in a busy
  /// real app. See [FakeChatSource.liveMessages].
  final ValueNotifier<bool> liveMessages = ValueNotifier(false);

  ChatKit get kit => switcher.kit!;

  FakeChatSource get source => _sources[switcher.active.id]!;

  bool get online => _online;

  ChatKit _createKit(ChatProfile profile) {
    final source =
        _sources.putIfAbsent(profile.id, () => FakeChatSource(me: profile.id))
          ..online = _online
          ..liveMessages = liveMessages.value;
    return ChatKit(
      currentUserId: profile.id,
      agentId: profile.agentId,
      source: source,
      uploader: FakeUploader(source),
      users: FakeUserResolver(),
      cache: _cache?.call(),
    );
  }

  Future<void> open() => switcher.open();

  /// Simulates losing or getting back the connection. The kit queues sends
  /// while offline and flushes them when back online.
  void setOnline({required bool online}) {
    _online = online;
    for (final source in _sources.values) {
      source.online = online;
    }
    switcher.setOnline(online: online);
  }

  /// Back to a fresh install: every profile's cache, drafts, queued sends
  /// and media are deleted, the fake servers start over with their sample
  /// chats, live messages stop, the connection is back and the personal
  /// profile is active.
  Future<void> reset() async {
    liveMessages.value = false;
    await switcher.clearAllUserData();
    for (final source in _sources.values) {
      await source.dispose();
    }
    _sources.clear();
    setOnline(online: true);
    await switcher.switchTo(FakeChatSource.personalId);
    await switcher.open();
  }

  Future<void> close() async {
    await switcher.close();
    switcher.dispose();
    liveMessages.dispose();
    for (final source in _sources.values) {
      await source.dispose();
    }
  }
}

/// Turns live incoming messages on and off; highlighted while on.
class LiveMessagesButton extends StatelessWidget {
  const LiveMessagesButton({required this.backend, super.key});

  final ExampleBackend backend;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: backend.liveMessages,
      builder: (context, live, _) => IconButton(
        isSelected: live,
        tooltip: live
            ? context.t.app.stopLiveMessages
            : context.t.app.startLiveMessages,
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.mark_chat_unread),
        onPressed: () => backend.liveMessages.value = !live,
      ),
    );
  }
}

/// Toggles the simulated connection; the icon shows the current state.
class ConnectionButton extends StatelessWidget {
  const ConnectionButton({required this.backend, super.key});

  final ExampleBackend backend;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: backend.switcher,
      builder: (context, _) {
        final online = backend.online;
        return IconButton(
          tooltip: online ? context.t.app.goOffline : context.t.app.goOnline,
          icon: Icon(online ? Icons.wifi : Icons.wifi_off),
          onPressed: () => backend.setOnline(online: !online),
        );
      },
    );
  }
}

/// Shown above the messages while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.kit, super.key});

  final ChatKit kit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: kit,
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: kit.isOnline
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.t.app.offlineBanner,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
      ),
    );
  }
}
