import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/backend.dart';
import 'package:flutter_chat_pro_example/custom/booking_card.dart';
import 'package:flutter_chat_pro_example/custom/offer_cards.dart';
import 'package:flutter_chat_pro_example/main.dart';
import 'package:flutter_chat_pro_example/style/style_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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
    final style = StyleSettings();
    addTearDown(style.dispose);
    await tester.pumpWidget(ChatKitExampleApp(backend: backend, style: style));
    await settle(tester, () => shows('Weekend trip'));
    expect(find.text('Big history (5 000 messages)'), findsOneWidget);

    // The style sheet restyles the screen behind it.
    ChatTheme themeOf(String text) =>
        ChatTheme.of(tester.element(find.text(text)));
    // Theme changes animate; frames run them to the end.
    Future<void> frames() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.byTooltip('Chat style'));
    await frames();
    final cards = find.widgetWithText(ChoiceChip, 'Cards');
    await tester.ensureVisible(cards);
    await frames();
    await tester.tap(cards);
    await frames();
    expect(style.tiles, ChatTiles.cards);
    final tile = themeOf('Weekend trip').roomTile;
    expect(tile.shape, isA<RoundedRectangleBorder>());
    expect(tile.margin, isNot(EdgeInsets.zero));
    style.zoom = 1.2;
    await frames();
    expect(themeOf('Weekend trip').scale, closeTo(1.2, 1e-9));
    style
      ..applyPreset(ChatPreset.classic)
      ..zoom = 1;
    await tester.tapAt(const Offset(20, 120));
    await frames();

    await tester.tap(find.text('Weekend trip'));
    await settle(
      tester,
      () => find.byType(ProductOfferCard).evaluate().isNotEmpty,
    );
    expect(find.text('Camping tent (4 people)'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);

    // The room was opened from the styled list: it follows the sheet live.
    ChatTheme roomTheme() =>
        ChatTheme.of(tester.element(find.byType(ChatComposer)));
    expect(roomTheme().outgoingBubble.radius, 18);
    style.bubbleRadius = 4;
    await frames();
    expect(roomTheme().outgoingBubble.radius, 4);
    style.reset();
    await frames();

    await tester.pageBack();
    await settle(tester, () => find.byType(InboxView).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));

    // One `offer` type drawn as another card, and a booking in a bubble.
    await tester.tap(find.text('Lemsa Shop').first);
    await settle(tester, () => find.byType(QuoteCard).evaluate().isNotEmpty);
    expect(find.text('Engraved wallet'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(BookingCard),
      ),
      findsOneWidget,
    );
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
