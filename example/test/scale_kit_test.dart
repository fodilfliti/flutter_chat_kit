import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_scale_kit/flutter_scale_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proof that the chat matches flutter_scale_kit exactly: with
/// `ChatScale(1.w, text: 1.sp)`, a chat size of 14 is `14.w` and a chat
/// font of 14 is `14.sp`, on phones, rotated phones and tablets, and after
/// every resize.
void main() {
  late ChatTheme chat;

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    ScaleKitBuilder(
      designWidth: 375,
      designHeight: 812,
      child: MaterialApp(
        home: ChatStyle(
          scale: (context) => ChatScale(1.w, text: 1.sp),
          child: Builder(
            builder: (context) {
              chat = context.chatTheme;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );

  void expectMatchesScaleKit() {
    const tolerance = 1e-9;
    expect(chat.size(14), closeTo(14.w, tolerance));
    expect(chat.fontSize(14), closeTo(14.sp, tolerance));
    expect(14.w, closeTo(14 * 1.w, tolerance));
    expect(14.sp, closeTo(14 * 1.sp, tolerance));
    // Design values inside the default theme scale the same way.
    expect(chat.outgoingBubble.radius, closeTo(18.w, tolerance));
    expect(chat.outgoingBubble.padding.left, closeTo(12.w, tolerance));
    expect(chat.roomTile.avatarSize, closeTo(52.w, tolerance));
    expect(chat.outgoingBubble.textStyle.fontSize, closeTo(16.sp, tolerance));
  }

  for (final (name, size) in [
    ('phone portrait', const Size(390, 844)),
    ('phone landscape', const Size(844, 390)),
    ('small phone', const Size(320, 640)),
    ('tablet', const Size(820, 1180)),
  ]) {
    testWidgets('matches .w and .sp on a $name', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      addTearDown(tester.view.reset);
      await pumpApp(tester);
      expectMatchesScaleKit();
    });
  }

  testWidgets('follows scale kit through rotation and resize', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    final portrait = chat.scale;
    expectMatchesScaleKit();

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expectMatchesScaleKit();
    // Landscape phones get scale kit's orientation boost; the chat too.
    expect(chat.scale, isNot(portrait));

    tester.view.physicalSize = const Size(820, 1180);
    await tester.pump();
    expectMatchesScaleKit();
  });

  testWidgets('a responsive app text theme is not scaled twice', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    // Same setup as the flutter_scale_theme_kit example app.
    await tester.pumpWidget(
      ScaleKitBuilder(
        designWidth: 375,
        designHeight: 812,
        child: Builder(
          builder: (context) {
            final base = ThemeData();
            return MaterialApp(
              theme: base.copyWith(
                textTheme: base.createResponsiveTextTheme(base.textTheme),
              ),
              home: ChatStyle(
                scale: (context) => ChatScale(1.w, text: 1.sp),
                child: Builder(
                  builder: (context) {
                    chat = context.chatTheme;
                    return const SizedBox();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(1.sp, isNot(closeTo(1, 0.01)));
    expect(chat.outgoingBubble.textStyle.fontSize, closeTo(16.sp, 1e-9));
  });
}
