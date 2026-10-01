import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/fake/fake_chat_source.dart';
import 'package:flutter_chat_kit_example/main.dart';
import 'package:flutter_chat_kit_example/style/style_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('reset demo brings back the sample chats and the default style', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = Directory.systemTemp.createTempSync('chat_kit_reset_');
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
    await settle(tester, () => shows('Weekend trip'));

    // A take: a sent message, a new look, no connection, the shop profile.
    await tester.tap(find.text('Weekend trip'));
    await settle(tester, () => find.byType(ChatComposer).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    final field = find.descendant(
      of: find.byType(ChatComposer),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Take one');
    // The send button grows in from the frame after typing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Send'));
    await settle(
      tester,
      () =>
          tester.widget<TextField>(field).controller!.text.isEmpty &&
          shows('Take one'),
    );
    await tester.pageBack();
    await settle(tester, () => find.byType(InboxView).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Take one'), findsWidgets);

    style
      ..applyPreset(ChatPreset.values.last)
      ..seed = Colors.red
      ..dark = true
      ..zoom = 1.3
      ..textScale = 1.2;
    await tester.tap(find.byTooltip('Turn on incoming messages'));
    await tester.pump();
    expect(backend.source.liveMessages, isTrue);
    expect(find.byTooltip('Turn off incoming messages'), findsOneWidget);
    final firstSource = backend.source..randomFailures = true;
    backend.switcher.switchTo(FakeChatSource.shopId).ignore();
    await settle(tester, () => shows('Omar Khelifi'));
    await tester.pump(const Duration(seconds: 1));
    backend.setOnline(online: false);
    bool offline() => find.textContaining('Offline:').evaluate().isNotEmpty;
    await settle(tester, offline);

    await tester.tap(find.byTooltip('Start style shuffle'));
    await tester.pump();
    expect(style.autoShuffle, isTrue);

    await tester.tap(find.byTooltip('Show menu'));
    await settle(tester, () => shows('Reset demo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Reset demo'));
    await settle(
      tester,
      () =>
          backend.switcher.active.id == FakeChatSource.personalId &&
          shows('Weekend trip'),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Take one'), findsNothing);
    expect(backend.online, isTrue);
    expect(offline(), isFalse);
    expect(backend.source, isNot(same(firstSource)));
    expect(backend.source.randomFailures, isFalse);
    expect(backend.liveMessages.value, isFalse);
    expect(backend.source.liveMessages, isFalse);
    expect(find.byTooltip('Turn on incoming messages'), findsOneWidget);
    expect(style.autoShuffle, isFalse);
    expect(style.preset, ChatPreset.classic);
    expect(style.seed, Colors.teal);
    expect(style.dark, isFalse);
    expect(style.screen, ScreenScale.off);
    expect(style.zoom, 1);
    expect(style.textScale, 1);

    await tester.pumpWidget(const SizedBox());
    var closed = false;
    backend.close().whenComplete(() => closed = true).ignore();
    await settle(tester, () => closed);
    await tester.pump(const Duration(seconds: 15));
  });
}
