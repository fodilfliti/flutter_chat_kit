import 'dart:async';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

class _Uploader implements ChatUploader {
  final List<String> uploads = [];

  /// Paths whose next upload fails with this failure.
  final Map<String, AppFailure> failOnce = {};

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    final path = attachment.localPath!;
    uploads.add(path);
    yield const UploadRunning(0.5);
    final failure = failOnce.remove(path);
    if (failure != null) throw failure;
    yield UploadDone(remoteUrl: 'https://cdn/$path');
  }
}

void main() {
  late FakeChatSource source;
  late DriftChatCache cache;
  late _Uploader uploader;
  late Outbox outbox;
  var now = _t0;

  const policy = RetryPolicy(maxAttempts: 3, jitter: 0);

  Outbox build() => Outbox(
    currentUserId: 'me',
    source: source,
    cache: cache,
    uploader: uploader,
    retryPolicy: policy,
    clock: () => now,
  );

  TextMessage text(String localId, {String room = 'r1', String body = 'hi'}) {
    return TextMessage(
      id: localId,
      localId: localId,
      roomId: room,
      authorId: 'me',
      createdAt: now,
      text: body,
    );
  }

  ImageMessage images(String localId, List<String> paths) {
    return ImageMessage(
      id: localId,
      localId: localId,
      roomId: 'r1',
      authorId: 'me',
      createdAt: now,
      images: [
        for (final p in paths) Attachment(mimeType: 'image/jpeg', localPath: p),
      ],
    );
  }

  Future<Message?> stored(String id) => cache.messageByAnyId(id);

  /// Sends [localId] and waits until it is confirmed.
  Future<Message> sent(String localId) async {
    await outbox.send(text(localId));
    await outbox.flush();
    return (await stored(localId))!;
  }

  setUp(() async {
    now = _t0;
    source = FakeChatSource()..clock = () => now;
    cache = memoryCache(clock: () => now);
    await cache.open('me');
    uploader = _Uploader();
    outbox = build();
  });

  tearDown(() async {
    await outbox.dispose();
    await source.dispose();
    await cache.close();
  });

  group('send', () {
    test('the row is visible before the source answers', () async {
      source.sendGate = Completer();
      final pending = await outbox.send(text('l1'));
      expect(pending.status, MessageStatus.pending);
      final shown = await stored('l1');
      expect(shown?.status.isLocal, isTrue);

      source.sendGate!.complete();
      await outbox.flush();
      final confirmed = await stored('l1');
      expect(confirmed?.id, 'srv-1');
      expect(confirmed?.localId, 'l1');
      expect(confirmed?.status, MessageStatus.sent);
      expect(await cache.messages('r1'), hasLength(1));
      expect(await cache.outbox(), isEmpty);
    });

    test('an echo that lands first is kept', () async {
      source.sendGate = Completer();
      await outbox.send(text('l1'));
      await pumpEventQueue();
      await cache.upsertMessages([
        text('l1', body: 'from server').copyWith(id: 'srv-9'),
      ]);
      source.sendGate!.complete();
      await outbox.flush();
      final message = await stored('l1') as TextMessage?;
      expect(message?.id, 'srv-9');
      expect(message?.text, 'from server');
      expect(await cache.outbox(), isEmpty);
    });

    test('uploads report progress and store remote urls', () async {
      final progress = <double?>[];
      outbox
          .progressOf('m1')
          .addListener(() => progress.add(outbox.progressOf('m1').value));
      await outbox.send(images('m1', ['a.jpg', 'b.jpg']));
      await outbox.flush();

      expect(progress, [0.0, 0.25, 0.75, 1.0, null]);
      final message = await stored('m1') as ImageMessage?;
      expect(message?.status, MessageStatus.sent);
      expect(message?.images.map((a) => a.remoteUrl), [
        'https://cdn/a.jpg',
        'https://cdn/b.jpg',
      ]);
      expect(message?.images.first.localPath, 'a.jpg');
      final sentImages = (source.sent.single as ImageMessage).images;
      expect(sentImages.every((a) => a.isUploaded), isTrue);
    });

    test('a retry does not upload finished files again', () async {
      uploader.failOnce['b.jpg'] = const NetworkFailure();
      await outbox.send(images('m1', ['a.jpg', 'b.jpg']));
      await outbox.flush();
      expect(uploader.uploads, ['a.jpg', 'b.jpg']);
      expect((await stored('m1'))?.status, MessageStatus.pending);

      now = now.add(policy.base);
      await outbox.flush();
      expect(uploader.uploads, ['a.jpg', 'b.jpg', 'b.jpg']);
      expect((await stored('m1'))?.status, MessageStatus.sent);
    });

    test('a file that is gone fails the send; retry says why', () async {
      final gone = <String>{'blob:old'};
      await outbox.dispose();
      outbox = Outbox(
        currentUserId: 'me',
        source: source,
        cache: cache,
        uploader: uploader,
        retryPolicy: policy,
        clock: () => now,
        fileAvailable: (a) async => !gone.contains(a.localPath),
      );
      await outbox.send(images('m1', ['blob:old']));
      await outbox.flush();
      expect(uploader.uploads, isEmpty);
      expect((await stored('m1'))?.status, MessageStatus.failed);
      expect(
        (await cache.outboxEntry(Outbox.sendKey('m1')))?.lastError,
        Outbox.fileUnavailable,
      );

      await expectLater(
        outbox.retry('m1'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fields['attachments'],
            'attachments',
            Outbox.fileUnavailable,
          ),
        ),
      );

      gone.clear();
      await outbox.retry('m1');
      expect((await stored('m1'))?.status, MessageStatus.sent);
    });

    test('attachment files read the same on every platform', () async {
      const plain = Attachment(mimeType: 'image/jpeg', localPath: 'x.jpg');
      expect(plain.file?.path, 'x.jpg');
      expect(plain.file?.mimeType, 'image/jpeg');
      const uploaded = Attachment(mimeType: 'image/jpeg', remoteUrl: 'u');
      expect(uploaded.file, isNull);
      expect(uploaded.readAsBytes, throwsStateError);
    });

    test('media without an uploader is rejected up front', () async {
      final bare = Outbox(currentUserId: 'me', source: source, cache: cache);
      addTearDown(bare.dispose);
      expect(
        () => bare.send(images('m1', ['a.jpg'])),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('retry', () {
    test('network failures back off, then fail after maxAttempts', () async {
      source.failNext = const NetworkFailure();
      await outbox.send(text('l1'));
      await outbox.flush();
      var entry = (await cache.outbox()).single;
      expect(entry.attempts, 1);
      expect(entry.nextAttemptAt, now.add(policy.base));
      expect((await stored('l1'))?.status, MessageStatus.pending);

      now = now.add(const Duration(seconds: 1));
      await outbox.flush();
      expect(source.sendCalls, 0);

      now = now.add(const Duration(seconds: 1));
      source.failNext = const TimeoutFailure();
      await outbox.flush();
      entry = (await cache.outbox()).single;
      expect(entry.attempts, 2);
      expect(entry.nextAttemptAt, now.add(policy.base * 2));

      now = now.add(policy.base * 2);
      source.failNext = const NetworkFailure();
      await outbox.flush();
      expect((await stored('l1'))?.status, MessageStatus.failed);
      entry = (await cache.outbox()).single;
      expect(entry.attempts, 3);
      expect(entry.nextAttemptAt, isNull);
    });

    test('a rejection fails at once; retry sends it', () async {
      source.failNext = const ValidationFailure({'text': 'too_long'});
      await outbox.send(text('l1'));
      await outbox.flush();
      expect((await stored('l1'))?.status, MessageStatus.failed);
      expect((await cache.outbox()).single.lastError, 'ValidationFailure');

      await outbox.flush();
      expect(source.sendCalls, 0);

      await outbox.retry('l1');
      expect((await stored('l1'))?.status, MessageStatus.sent);
      expect(await cache.outbox(), isEmpty);
    });

    test('an expired token pauses the queue until retryAll', () async {
      var expired = 0;
      await outbox.dispose();
      outbox = Outbox(
        currentUserId: 'me',
        source: source,
        cache: cache,
        uploader: uploader,
        retryPolicy: policy,
        clock: () => now,
        onAuthExpired: () => expired++,
      );
      source.failSend['l1'] = const AuthFailure(AuthReason.expired);
      await outbox.send(text('l1'));
      await outbox.send(text('l2'));
      await outbox.flush();

      expect(outbox.isPausedForAuth, isTrue);
      expect(expired, 1);
      expect((await stored('l1'))?.status, MessageStatus.pending);
      expect((await stored('l2'))?.status, MessageStatus.pending);
      expect(source.sendCalls, 0);

      await outbox.send(text('l3'));
      await outbox.flush();
      expect(source.sendCalls, 0, reason: 'nothing leaves while paused');

      await outbox.retryAll();
      expect(outbox.isPausedForAuth, isFalse);
      expect(source.sendCalls, 3);
      for (final id in ['l1', 'l2', 'l3']) {
        expect((await stored(id))?.status, MessageStatus.sent);
      }
    });

    test('a disabled account fails instead of pausing', () async {
      source.failSend['l1'] = const AuthFailure(AuthReason.disabled);
      await outbox.send(text('l1'));
      await outbox.flush();
      expect(outbox.isPausedForAuth, isFalse);
      expect((await stored('l1'))?.status, MessageStatus.failed);
    });

    test('discard removes a failed message; a sent one stays', () async {
      source.failNext = const PermissionFailure('room');
      await outbox.send(text('l1'));
      await outbox.flush();
      expect(await outbox.discard('l1'), isTrue);
      expect(await stored('l1'), isNull);
      expect(await cache.outbox(), isEmpty);

      await sent('l2');
      expect(await outbox.discard('l2'), isFalse);
      expect(await stored('l2'), isNotNull);
    });

    test('a restart resumes pending entries', () async {
      outbox.setOnline(online: false);
      await outbox.send(text('l1'));
      await outbox.flush();
      expect(source.sendCalls, 0);
      await outbox.dispose();

      outbox = build();
      await outbox.flush();
      expect((await stored('l1'))?.status, MessageStatus.sent);
    });

    test('a waiting entry holds back its room only', () async {
      source.failSend['a1'] = const NetworkFailure();
      await outbox.send(text('a1'));
      await outbox.send(text('a2'));
      await outbox.send(text('b1', room: 'r2'));
      await outbox.flush();
      expect([for (final m in source.sent) m.localId], ['b1']);

      now = now.add(policy.base);
      await outbox.flush();
      expect([for (final m in source.sent) m.localId], ['b1', 'a1', 'a2']);
    });

    test('retryAll resends failed messages', () async {
      source.failNext = const ServerFailure(status: 500);
      await outbox.send(text('l1'));
      await outbox.flush();
      expect((await stored('l1'))?.status, MessageStatus.failed);

      await outbox.retryAll();
      expect((await stored('l1'))?.status, MessageStatus.sent);
    });
  });

  group('edit, delete, react', () {
    test('an edit of an unsent message is merged into the send', () async {
      outbox.setOnline(online: false);
      await outbox.send(text('l1'));
      await outbox.edit(text('l1', body: 'fixed'));
      expect((await cache.outbox()).map((e) => e.op), [OutboxOp.send]);

      outbox.setOnline(online: true);
      await outbox.flush();
      expect((source.sent.single as TextMessage).text, 'fixed');
      expect(source.edits, isEmpty);
    });

    test('an edit shows at once and reaches the source', () async {
      final message = await sent('l1');
      await outbox.edit((message as TextMessage).copyWith(text: 'edited'));
      await outbox.flush();
      expect(source.edits.single.id, 'srv-1');
      final edited = await stored('l1') as TextMessage?;
      expect(edited?.text, 'edited');
      expect(edited?.isEdited, isTrue);
      expect(edited?.status, MessageStatus.sent);
      expect(await cache.outbox(), isEmpty);
    });

    test('a rejected edit is reverted and reported', () async {
      final message = await sent('l1');
      final errors = <OutboxError>[];
      final sub = outbox.errors.listen(errors.add);
      addTearDown(sub.cancel);

      source.failNext = const PermissionFailure('message');
      await outbox.edit((message as TextMessage).copyWith(text: 'edited'));
      await outbox.flush();
      expect((await stored('l1') as TextMessage?)?.text, 'hi');
      expect((await stored('l1'))?.isEdited, isFalse);
      expect(errors.single.entry.op, OutboxOp.edit);
      expect(errors.single.failure, isA<PermissionFailure>());
      expect(await cache.outbox(), isEmpty);
    });

    test('deleting an unsent message drops it; a sent one is marked', () async {
      outbox.setOnline(online: false);
      await outbox.send(text('l1'));
      await outbox.delete('r1', 'l1');
      expect(await stored('l1'), isNull);
      expect(await cache.outbox(), isEmpty);

      outbox.setOnline(online: true);
      await sent('l2');
      await outbox.delete('r1', 'l2');
      expect((await stored('l2'))?.isDeleted, isTrue);
      await outbox.flush();
      expect(source.deleteCalls.single, ('r1', 'srv-1'));
      expect(await cache.outbox(), isEmpty);
    });

    test('a rejected delete restores the message', () async {
      await sent('l1');
      source.failNext = const PermissionFailure('message');
      await outbox.delete('r1', 'l1');
      await outbox.flush();
      expect((await stored('l1'))?.isDeleted, isFalse);
    });

    test('reactions are optimistic; opposite queued writes cancel', () async {
      await sent('l1');
      outbox.setOnline(online: false);
      await outbox.react('r1', 'l1', '👍', add: true);
      expect((await stored('l1'))?.reactions['👍'], {'me'});
      await outbox.react('r1', 'l1', '👍', add: false);
      expect((await stored('l1'))?.reactions, isEmpty);
      expect(await cache.outbox(), isEmpty);

      await outbox.react('r1', 'l1', '❤️', add: true);
      outbox.setOnline(online: true);
      await outbox.flush();
      expect(source.reactCalls.single, ('r1', 'srv-1', '❤️', true));
      expect((await stored('l1'))?.reactions['❤️'], {'me'});
    });

    test('a reaction on an unsent message waits for the send', () async {
      source.failNext = const NetworkFailure();
      await outbox.send(text('l1'));
      await outbox.react('r1', 'l1', '👍', add: true);
      await outbox.flush();
      expect(source.reactCalls, isEmpty);

      now = now.add(policy.base);
      await outbox.flush();
      expect(source.reactCalls.single, ('r1', 'srv-1', '👍', true));
    });
  });

  group('RetryPolicy', () {
    test('doubles up to max, with bounded jitter', () {
      const p = RetryPolicy(
        base: Duration(seconds: 1),
        max: Duration(seconds: 5),
        jitter: 0,
      );
      expect(
        [for (var i = 1; i <= 5; i++) p.delay(i).inSeconds],
        [1, 2, 4, 5, 5],
      );
      const j = RetryPolicy(base: Duration(seconds: 10));
      for (var i = 0; i < 20; i++) {
        final d = j.delay(1).inMilliseconds;
        expect(d, inInclusiveRange(8000, 12000));
      }
      expect(p.isRetryable(const NetworkFailure()), isTrue);
      expect(p.isRetryable(const ValidationFailure({})), isFalse);
    });
  });

  group('ChatKit', () {
    test('wires connectivity and retryPending to the outbox', () async {
      final kit = ChatKit(
        currentUserId: 'me',
        source: source,
        cache: memoryCache(clock: () => now),
        retryPolicy: policy,
      );
      await kit.open();
      addTearDown(kit.close);

      kit.setOnline(online: false);
      expect(kit.outbox.isOnline, isFalse);

      source.failNext = const ServerFailure();
      kit.setOnline(online: true);
      await kit.outbox.send(text('l1'));
      await kit.outbox.flush();
      expect(
        (await kit.cache.messageByAnyId('l1'))?.status,
        MessageStatus.failed,
      );

      await kit.retryPending();
      expect(
        (await kit.cache.messageByAnyId('l1'))?.status,
        MessageStatus.sent,
      );
    });
  });
}
