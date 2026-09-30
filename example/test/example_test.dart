import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/main.dart';
import 'package:flutter_chat_kit_example/offer/offer_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alternates real time (the database) and frames until [until] holds.
Future<void> settle(WidgetTester tester, bool Function() until) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (until()) return;
  }
  fail('condition not reached');
}

bool shows(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  testWidgets('inbox lists the rooms and opens the group with its offer', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = Directory.systemTemp.createTempSync('chat_kit_example_');
    addTearDown(() => temp.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    final backend = ExampleBackend(
      cache: () =>
          DriftChatCache(executorFactory: (_) => NativeDatabase.memory()),
    );
    await tester.pumpWidget(ChatKitExampleApp(backend: backend));
    await settle(tester, () => shows('Weekend trip'));
    expect(find.text('Big history (5 000 messages)'), findsOneWidget);

    await tester.tap(find.text('Weekend trip'));
    await settle(tester, () => find.byType(OfferCard).evaluate().isNotEmpty);
    expect(find.text('Camping tent (4 people)'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);

    await tester.pageBack();
    await settle(tester, () => find.byType(InboxView).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Chats'));
    await settle(tester, () => !shows('Weekend trip'));
    expect(find.text('Big history (5 000 messages)'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Friends'));
    await settle(tester, () => shows('Weekend trip'));
    expect(find.text('Big history (5 000 messages)'), findsNothing);

    // Answer for the shop: its customers, and who of the staff replied.
    await tester.tap(find.byType(ChatProfileMenuButton));
    await settle(tester, () => shows('Business'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Lemsa Shop').last);
    await settle(tester, () => shows('Omar Khelifi'));
    expect(backend.switcher.active.id, 'shop');
    expect(find.text('Weekend trip'), findsNothing);
    await settle(tester, () => shows('Sara (staff): From 9am to 7pm 🙂'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Nadia Saidi'));
    await settle(tester, () => shows('Sara (staff)'));
    expect(find.text('From 9am to 7pm 🙂'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, () => find.byType(InboxView).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    var closed = false;
    backend.close().whenComplete(() => closed = true).ignore();
    await settle(tester, () => closed);
    // Outlives the image cache's 10 s cleanup timer.
    await tester.pump(const Duration(seconds: 15));
  });
}
