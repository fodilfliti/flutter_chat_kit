import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/backend.dart';
import 'package:flutter_chat_pro_example/i18n/chat_strings.dart';
import 'package:flutter_chat_pro_example/i18n/strings.g.dart';
import 'package:flutter_chat_pro_example/main.dart';
import 'package:flutter_chat_pro_example/style/style_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every text a [ChatStrings] can produce, with sample arguments.
Map<String, String> textsOf(ChatStrings s) => {
  'typeMessage': s.typeMessage,
  'today': s.today,
  'yesterday': s.yesterday,
  'newMessages': s.newMessages,
  'reply': s.reply,
  'copy': s.copy,
  'copied': s.copied,
  'edit': s.edit,
  'delete': s.delete,
  'retry': s.retry,
  'cancel': s.cancel,
  'send': s.send,
  'failedToSend': s.failedToSend,
  'messageDeleted': s.messageDeleted,
  'unsupportedMessage': s.unsupportedMessage,
  'edited': s.edited,
  'editing': s.editing,
  'you': s.you,
  'online': s.online,
  'slideToCancel': s.slideToCancel,
  'searchChats': s.searchChats,
  'noChats': s.noChats,
  'noMessages': s.noMessages,
  'loadFailed': s.loadFailed,
  'startOfConversation': s.startOfConversation,
  'scrollToBottom': s.scrollToBottom,
  'photo': s.photo,
  'video': s.video,
  'voice': s.voice,
  'file': s.file,
  'camera': s.camera,
  'gallery': s.gallery,
  'attachmentTooLarge': s.attachmentTooLarge,
  'fileUnavailable': s.fileUnavailable,
  'compressing': s.compressing,
  'readMore': s.readMore,
  'readLess': s.readLess,
  'replyUnavailable': s.replyUnavailable,
  'statusPending': s.statusPending,
  'statusSent': s.statusSent,
  'statusDelivered': s.statusDelivered,
  'statusSeen': s.statusSeen,
  'messageOptions': s.messageOptions,
  'save': s.save,
  'saved': s.saved,
  'download': s.download,
  'downloadFailed': s.downloadFailed,
  'play': s.play,
  'pause': s.pause,
  'close': s.close,
  'attach': s.attach,
  'removeAttachment': s.removeAttachment,
  'recordVoice': s.recordVoice,
  'holdToRecord': s.holdToRecord,
  'microphoneDenied': s.microphoneDenied,
  'slideUpToLock': s.slideUpToLock,
  'stopRecording': s.stopRecording,
  'back': s.back,
  'forward': s.forward,
  'select': s.select,
  'pin': s.pin,
  'unpin': s.unpin,
  'mute': s.mute,
  'unmute': s.unmute,
  'clearSearch': s.clearSearch,
  'noResults': s.noResults,
  'loadChatsFailed': s.loadChatsFailed,
  'switchProfile': s.switchProfile,
  'businessProfile': s.businessProfile,
  'typing 1': s.typing(['Sara']),
  'typing 2': s.typing(['Sara', 'Omar']),
  'typing 5': s.typing(['a', 'b', 'c', 'd', 'e']),
  'system': s.system('room_created', {'name': 'Amina', 'title': 'Trip'}),
  'lastSeen': s.lastSeen('10:00'),
  'photos 1': s.photos(1),
  'photos 3': s.photos(3),
  'reaction 1': s.reaction('👍', 1),
  'reaction 4': s.reaction('👍', 4),
  'reactWith': s.reactWith('👍'),
  'mediaPosition': s.mediaPosition(3, 12),
  'members 1': s.members(1),
  'members 4': s.members(4),
  'unreadCount 1': s.unreadCount(1),
  'unreadCount 12': s.unreadCount(12),
  'customPreview': '${s.customPreview?.call('offer', {'title': 'Tent'})}',
};

final _arabic = RegExp('[\u0600-\u06FF]');

Future<ExampleBackend> _pumpApp(WidgetTester tester) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final temp = Directory.systemTemp.createTempSync('chat_kit_i18n_');
  addTearDown(() => temp.deleteSync(recursive: true));
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => temp.path,
  );
  final backend = ExampleBackend(
    cache: () =>
        DriftChatCache(executorFactory: (_) => NativeDatabase.memory()),
  );
  final style = StyleSettings();
  addTearDown(style.dispose);
  await tester.pumpWidget(ChatKitExampleApp(backend: backend, style: style));
  return backend;
}

Future<void> _closeApp(WidgetTester tester, ExampleBackend backend) async {
  await tester.pumpWidget(const SizedBox());
  var closed = false;
  backend.close().whenComplete(() => closed = true).ignore();
  await settle(tester, () => closed);
  await tester.pump(const Duration(seconds: 15));
}

void main() {
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('every chat text is translated', () {
    final english = textsOf(buildChatStrings(AppLocale.en.buildSync()));

    test('Arabic: no text is left in English', () {
      final arabic = textsOf(buildChatStrings(AppLocale.ar.buildSync()));
      for (final MapEntry(:key, :value) in arabic.entries) {
        expect(value, matches(_arabic), reason: key);
        expect(value, isNot(english[key]), reason: key);
      }
    });

    test('French: only words that are the same in both languages', () {
      final french = textsOf(buildChatStrings(AppLocale.fr.buildSync()));
      final same = {
        for (final MapEntry(:key, :value) in french.entries)
          if (value == english[key]) key,
      };
      expect(same, {'typeMessage', 'photo', 'pause', 'photos 1', 'photos 3'});
    });

    test('Arabic plurals use their own forms', () {
      final s = buildChatStrings(AppLocale.ar.buildSync());
      expect(s.members(1), 'عضو واحد');
      expect(s.members(2), 'عضوان');
      expect(s.members(4), '4 أعضاء');
      expect(s.members(11), '11 عضوًا');
      expect(s.members(100), '100 عضو');
    });
  });

  testWidgets('switching the language translates the running app', (
    tester,
  ) async {
    final backend = await _pumpApp(tester);
    await settle(tester, () => shows('Weekend trip'));
    expect(find.text('All'), findsOneWidget);

    LocaleSettings.setLocaleSync(AppLocale.ar);
    await settle(tester, () => shows('الكل'));
    final inbox = tester.element(find.byType(InboxView));
    expect(Directionality.of(inbox), TextDirection.rtl);
    expect(find.textContaining('المحادثات'), findsOneWidget);
    expect(find.text('All'), findsNothing);
    expect(find.textContaining('Chats'), findsNothing);

    await tester.tap(find.text('Weekend trip'));
    await settle(tester, () => shows('4 أعضاء'));
    expect(find.text('رسالة'), findsOneWidget);
    // The group's first message is a system message, above the screen.
    const created = 'أنشأ Amina المجموعة «Weekend trip»';
    final list = find.byType(ChatMessageList);
    await settle(tester, () {
      if (!shows(created)) {
        tester.drag(list, const Offset(0, 300)).ignore();
      }
      return shows(created);
    });
    final days = [
      for (final e in find.byType(DateSeparator).evaluate())
        (e.widget as DateSeparator).label,
    ];
    expect(days, isNotEmpty);
    expect(days, everyElement(matches(_arabic)));

    // The attach sheet: the kit's options and the app's custom ones.
    await tester.tap(find.byTooltip('إرفاق'));
    await settle(tester, () => shows('الكاميرا'));
    expect(find.text('المعرض'), findsOneWidget);
    expect(find.text('عرض سعر'), findsOneWidget);
    expect(find.text('موعد'), findsOneWidget);
    await tester.tapAt(const Offset(400, 40));
    await settle(tester, () => !shows('الكاميرا'));

    LocaleSettings.setLocaleSync(AppLocale.fr);
    await settle(tester, () => shows('4 membres'));
    expect(
      find.text('Amina a créé le groupe « Weekend trip »'),
      findsOneWidget,
    );
    final room = tester.element(find.byType(ChatComposer));
    expect(Directionality.of(room), TextDirection.ltr);

    await tester.tap(find.byTooltip('Retour'));
    await settle(tester, () => shows('Toutes'));
    expect(find.textContaining('Discussions'), findsOneWidget);

    await _closeApp(tester, backend);
  });
}
