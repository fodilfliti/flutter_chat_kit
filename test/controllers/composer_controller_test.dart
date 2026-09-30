import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late ChatRoomController room;

  ComposerController composer() =>
      ComposerController(room, draftDebounce: const Duration(milliseconds: 20));

  setUp(() async {
    h = Harness();
    await h.open();
    room = h.kit.room('r1');
    await room.ready;
  });

  tearDown(() async {
    room.dispose();
    await h.close();
  });

  test('typing is throttled and stops after idle', () async {
    final c = composer();
    await c.restored;
    c.text.text = 'h';
    c.text.text = 'he';
    expect(h.source.typingCalls, [('r1', true)]);

    h.now = h.now.add(const Duration(seconds: 3));
    c.text.text = 'hel';
    expect(h.source.typingCalls, [('r1', true), ('r1', true)]);

    await until(() => h.source.typingCalls.length == 3);
    expect(h.source.typingCalls.last, ('r1', false));
    expect(c.hasPendingTimers, isFalse);
    c.dispose();
  });

  test('the draft and reply target survive a new composer', () async {
    h.source.receive(msg(1));
    await until(() => room.messages.isNotEmpty);

    final c = composer();
    await c.restored;
    c
      ..reply(room.messages.single)
      ..text.text = 'draft';
    expect(c.hasPendingTimers, isTrue);
    c.dispose();
    expect(c.hasPendingTimers, isFalse);
    await until(() => h.source.typingCalls.lastOrNull == ('r1', false));

    final again = composer();
    addTearDown(again.dispose);
    await again.restored;
    await until(() => again.text.text == 'draft');
    expect(again.replyTo?.id, msg(1).id);
  });

  test('reply then submit sends with replyToId and clears', () async {
    h.source.receive(msg(1));
    await until(() => room.messages.isNotEmpty);
    final c = composer();
    addTearDown(c.dispose);
    await c.restored;

    expect(c.canSend, isFalse);
    c
      ..reply(room.messages.single)
      ..text.text = 'answer';
    expect(c.canSend, isTrue);
    await c.submit();
    expect(c.text.text, isEmpty);
    expect(c.replyTo, isNull);
    await until(() => room.messages.length == 2);
    final sent = room.messages.first as TextMessage;
    expect(sent.text, 'answer');
    expect(sent.replyToId, msg(1).id);
    expect(await h.kit.cache.draft('r1'), isNull);
  });

  test(
    'edit fills the field, keeps the draft, and replaces the text',
    () async {
      final c = composer();
      addTearDown(c.dispose);
      await c.restored;
      await room.sendText('first');
      await until(() => room.messages.length == 1);

      c.text.text = 'unfinished';
      c.startEdit(room.messages.single);
      expect(c.text.text, 'first');
      expect(c.canSend, isFalse);
      c.text.text = 'first!';
      expect(c.canSend, isTrue);
      await c.submit();

      expect(c.isEditing, isFalse);
      expect(c.text.text, 'unfinished');
      await until(() => (room.messages.single as TextMessage).text == 'first!');

      c
        ..startEdit(room.messages.single)
        ..cancel();
      expect(c.text.text, 'unfinished');
    },
  );

  test('staged files are sent with the text as caption', () async {
    final c = composer();
    addTearDown(c.dispose);
    await c.restored;
    const image = Attachment(mimeType: 'image/png', remoteUrl: 'https://i/1');
    c.stage([image]);
    expect(c.canSend, isTrue);
    c.text.text = 'caption';
    await c.submit();
    expect(c.staged, isEmpty);
    await until(() => room.messages.length == 1);
    expect((room.messages.single as ImageMessage).caption, 'caption');
  });
}
