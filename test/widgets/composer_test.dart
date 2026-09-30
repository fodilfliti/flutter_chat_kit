import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';
import 'widget_harness.dart';

class _Uploader implements ChatUploader {
  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    yield UploadDone(remoteUrl: 'https://cdn.test/$localId');
  }
}

class _FakeRecorder implements RecorderBackend {
  String? path;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String path) async {
    this.path = path;
    File(path).writeAsStringSync('audio');
  }

  @override
  Future<String?> stop() async => path;

  @override
  Stream<double> amplitudes(Duration interval) => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  late Harness h;
  late ChatRoomController room;
  late ComposerController composer;
  late Directory temp;
  late _FakeRecorder backend;
  late VoiceRecorderController recorder;
  late DateTime recorderNow;

  Future<void> open(
    WidgetTester tester, {
    bool uploads = true,
    List<Message> messages = const [],
    AttachmentPicker? picker,
    List<AttachmentOption> extra = const [],
    bool? sendOnEnter,
  }) async {
    h = Harness(uploader: uploads ? _Uploader() : null);
    h.source.seedMessages('r1', messages);
    await drive(tester, h.open());
    room = h.kit.room('r1');
    await drive(tester, room.ready);
    composer = ComposerController(room);
    await drive(tester, composer.restored);
    temp = Directory.systemTemp.createTempSync('chat_composer_');
    backend = _FakeRecorder();
    recorderNow = DateTime.utc(2026, 9, 30);
    recorder = VoiceRecorderController(
      backend: backend,
      tempDirectory: () async => temp,
      clock: () => recorderNow,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              ChatComposer(
                controller: composer,
                recorder: recorder,
                onAttachmentPick: picker,
                extraAttachmentOptions: extra,
                sendOnEnter: sendOnEnter,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    composer.dispose();
    recorder.dispose();
    room.dispose();
    await drive(tester, h.close());
    await tester.pump(const Duration(seconds: 3));
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }

  TextMessage mine(String text) => TextMessage(
    id: 'm1',
    localId: 'm1',
    roomId: 'r1',
    authorId: 'me',
    createdAt: t0,
    text: text,
  );

  testWidgets('typing swaps the mic for the send button', (tester) async {
    await open(tester);
    expect(find.byType(VoiceRecordButton), findsOneWidget);
    expect(find.byTooltip('Send'), findsNothing);
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byType(VoiceRecordButton), findsNothing);
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pumpAndSettle();
    expect(find.byType(VoiceRecordButton), findsOneWidget);
    await close(tester);
  });

  testWidgets('without an uploader there is no mic and no attach', (
    tester,
  ) async {
    await open(tester, uploads: false);
    expect(find.byType(VoiceRecordButton), findsNothing);
    expect(find.byTooltip('Attach'), findsNothing);
    final send = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(send.onPressed, isNull);
    await close(tester);
  });

  testWidgets('send clears the text and the draft', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send'));
    await settle(
      tester,
      until: () => h.source.sent.any((m) => m is TextMessage),
    );
    expect((h.source.sent.single as TextMessage).text, 'hello');
    await settle(tester);
    expect(composer.text.text, isEmpty);
    final draft = await drive(tester, h.kit.cache.draft('r1'));
    expect(draft?.text ?? '', isEmpty);
    await close(tester);
  });

  testWidgets('the reply banner shows the author and cancels', (tester) async {
    final quoted = msg(1);
    await open(tester, messages: [quoted]);
    composer.reply(quoted);
    await tester.pump();
    expect(find.byType(ReplyEditBanner), findsOneWidget);
    expect(find.text('User u2'), findsOneWidget);
    expect(find.text(quoted.text), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();
    expect(find.byType(ReplyEditBanner), findsNothing);
    expect(composer.replyTo, isNull);
    await close(tester);
  });

  testWidgets('editing pre-fills the text and submits an edit', (tester) async {
    final original = mine('helo');
    await open(tester, messages: [original]);
    composer.startEdit(original);
    await tester.pumpAndSettle();
    expect(find.text('Editing'), findsOneWidget);
    expect(composer.text.text, 'helo');
    expect(find.byType(VoiceRecordButton), findsNothing);
    expect(find.byTooltip('Attach'), findsNothing);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send'));
    await settle(tester, until: () => h.source.edits.isNotEmpty);
    expect((h.source.edits.single as TextMessage).text, 'hello');
    await close(tester);
  });

  testWidgets('the attachment picker override stages the files', (
    tester,
  ) async {
    final sources = <AttachmentSource>[];
    await open(
      tester,
      picker: (context, source) async {
        sources.add(source);
        return const [
          Attachment(
            mimeType: 'application/pdf',
            localPath: '/tmp/report.pdf',
            name: 'report.pdf',
            size: 10,
          ),
        ];
      },
    );
    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(sources, [AttachmentSource.gallery]);
    expect(composer.staged, hasLength(1));
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(composer.staged, isEmpty);
    await close(tester);
  });

  testWidgets('an extra attachment option calls back', (tester) async {
    var offers = 0;
    await open(
      tester,
      extra: [
        AttachmentOption(
          icon: Icons.local_offer_outlined,
          label: 'Offer',
          onSelected: () => offers++,
        ),
      ],
    );
    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offer'));
    await tester.pumpAndSettle();
    expect(offers, 1);
    await close(tester);
  });

  group('voice', () {
    Future<TestGesture> hold(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(VoiceRecordButton)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      return gesture;
    }

    testWidgets('a short press shows the hint', (tester) async {
      await open(tester);
      await tester.tap(find.byType(VoiceRecordButton));
      await tester.pump();
      expect(find.text('Hold to record, release to send'), findsOneWidget);
      expect(recorder.state, RecorderState.idle);
      await close(tester);
    });

    testWidgets('holding records and releasing sends', (tester) async {
      await open(tester);
      final gesture = await hold(tester);
      expect(recorder.state, RecorderState.recording);
      expect(find.text('Slide to cancel'), findsOneWidget);
      recorderNow = recorderNow.add(const Duration(seconds: 3));
      await gesture.up();
      await settle(
        tester,
        until: () => h.source.sent.any((m) => m is AudioMessage),
      );
      final sent = h.source.sent.whereType<AudioMessage>().single;
      expect(sent.duration, const Duration(seconds: 3));
      expect(recorder.state, RecorderState.idle);
      expect(find.byType(TextField), findsOneWidget);
      await close(tester);
    });

    testWidgets('sliding to the start cancels and deletes', (tester) async {
      await open(tester);
      final gesture = await hold(tester);
      final path = backend.path!;
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(recorder.state, RecorderState.idle);
      expect(File(path).existsSync(), isFalse);
      expect(h.source.sent, isEmpty);
      await close(tester);
    });

    testWidgets('sliding up locks; send finishes the recording', (
      tester,
    ) async {
      await open(tester);
      final gesture = await hold(tester);
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(recorder.state, RecorderState.locked);
      expect(find.byTooltip('Stop recording'), findsOneWidget);
      recorderNow = recorderNow.add(const Duration(seconds: 2));
      // The recorder ticks every 100 ms, so pumpAndSettle would not return.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Send'));
      await settle(
        tester,
        until: () => h.source.sent.any((m) => m is AudioMessage),
      );
      expect(recorder.state, RecorderState.idle);
      await close(tester);
    });

    testWidgets('a too-short recording is discarded with the hint', (
      tester,
    ) async {
      await open(tester);
      final gesture = await hold(tester);
      recorderNow = recorderNow.add(const Duration(milliseconds: 400));
      await gesture.up();
      await settle(tester);
      expect(find.text('Hold to record, release to send'), findsOneWidget);
      expect(h.source.sent, isEmpty);
      await close(tester);
    });
  });

  group('keyboard', () {
    testWidgets('Enter sends; Shift+Enter does not', (tester) async {
      await open(tester, sendOnEnter: true);
      await tester.enterText(find.byType(TextField), 'line');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(h.source.sent, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(
        tester,
        until: () => h.source.sent.any((m) => m is TextMessage),
      );
      await close(tester);
    });

    testWidgets('Esc cancels the reply', (tester) async {
      final quoted = msg(1);
      await open(tester, messages: [quoted], sendOnEnter: true);
      composer.reply(quoted);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(composer.replyTo, isNull);
      await close(tester);
    });
  });
}
