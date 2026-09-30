import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/fake/fake_chat_source.dart';
import 'package:flutter_chat_kit_example/fake/fake_uploader.dart';
import 'package:flutter_chat_kit_example/offer/offer_card.dart';

/// Texts shared by the inbox and the rooms. A real app passes its own
/// translations here (for example from slang or intl).
const exampleStrings = ChatStrings(customPreview: customPreview);

/// The fake backend of one signed-in account, which chats as two profiles:
/// its personal profile and "Lemsa Shop", a business it answers for along
/// with other staff. Only the active profile's kit is open.
class ExampleBackend {
  /// `cache` builds the local store of each kit; tests pass in-memory ones.
  ExampleBackend({this._cache}) {
    switcher = ChatProfileSwitcher(profiles: profiles, createKit: _createKit);
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

  ChatKit get kit => switcher.kit!;

  FakeChatSource get source => _sources[switcher.active.id]!;

  bool get online => _online;

  ChatKit _createKit(ChatProfile profile) {
    final source = _sources.putIfAbsent(
      profile.id,
      () => FakeChatSource(me: profile.id),
    )..online = _online;
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

  Future<void> close() async {
    await switcher.close();
    switcher.dispose();
    for (final source in _sources.values) {
      await source.dispose();
    }
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
          tooltip: online ? 'Go offline' : 'Go online',
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
                  'Offline: messages are queued and sent when you reconnect.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
      ),
    );
  }
}
