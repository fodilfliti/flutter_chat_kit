import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/fake/fake_chat_source.dart';
import 'package:flutter_chat_kit_example/fake/fake_uploader.dart';
import 'package:flutter_chat_kit_example/offer/offer_card.dart';

/// Texts shared by the inbox and the rooms. A real app passes its own
/// translations here (for example from slang or intl).
const exampleStrings = ChatStrings(customPreview: customPreview);

/// The fake backend and the kit, created once per signed-in user.
class ExampleBackend {
  ExampleBackend({ChatCache? cache}) : source = FakeChatSource() {
    kit = ChatKit(
      currentUserId: FakeChatSource.me,
      source: source,
      uploader: FakeUploader(source),
      users: FakeUserResolver(),
      cache: cache,
    );
  }

  final FakeChatSource source;
  late final ChatKit kit;

  bool get online => source.online;

  /// Simulates losing or getting back the connection. The kit queues sends
  /// while offline and flushes them when back online.
  void setOnline({required bool online}) {
    source.online = online;
    kit.setOnline(online: online);
  }

  Future<void> close() async {
    await kit.close();
    await source.dispose();
  }
}

/// Toggles the simulated connection; the icon shows the current state.
class ConnectionButton extends StatelessWidget {
  const ConnectionButton({required this.backend, super.key});

  final ExampleBackend backend;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: backend.kit,
      builder: (context, _) {
        final online = backend.kit.isOnline;
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
