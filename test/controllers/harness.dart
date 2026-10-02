import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

final t0 = DateTime.utc(2026, 9, 30, 12);

DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

TextMessage msg(
  int i, {
  String room = 'r1',
  String author = 'u2',
  int? second,
}) {
  final id = '$room-m${i.toString().padLeft(3, '0')}';
  return TextMessage(
    id: id,
    localId: id,
    roomId: room,
    authorId: author,
    createdAt: at(second ?? i),
    text: id,
  );
}

class NameResolver implements ChatUserResolver {
  @override
  Future<List<ChatUser>> resolve(Set<String> ids) async => [
    for (final id in ids) ChatUser(id: id, name: 'User $id'),
  ];
}

/// A kit on an in-memory cache and a fake source, with short timings.
class Harness {
  Harness({
    ChatConfig? config,
    ChatUploader? uploader,
    String currentUserId = 'me',
    String? agentId,
  }) {
    source = FakeChatSource()..clock = () => now;
    kit = ChatKit(
      currentUserId: currentUserId,
      agentId: agentId,
      source: source,
      uploader: uploader,
      users: NameResolver(),
      cache: memoryCache(clock: () => now),
      clock: () => now,
      retryPolicy: const RetryPolicy(jitter: 0),
      config:
          config ??
          const ChatConfig(
            pageSize: 10,
            roomsPageSize: 2,
            searchDebounce: Duration(milliseconds: 30),
            highlightDuration: Duration(milliseconds: 30),
            typingTimeout: Duration(milliseconds: 60),
          ),
    );
  }

  late final FakeChatSource source;
  late final ChatKit kit;
  DateTime now = at(1000);

  Future<void> open() => kit.open();

  Future<void> close() async {
    await kit.close();
    await source.dispose();
  }
}

/// Polls [test] until it holds (real time, up to about two seconds).
Future<void> until(bool Function() test, {String? reason}) async {
  for (var i = 0; i < 400 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(test(), isTrue, reason: reason);
}

/// Swallows a failure the test expects to be reported elsewhere.
Future<void> ignoreFailure(Future<void> future) async {
  try {
    await future;
  } on AppFailure {
    // Expected.
  }
}
