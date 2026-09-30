import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ChatTheme> themeIn(WidgetTester tester, ThemeData data) async {
    late ChatTheme result;
    await tester.pumpWidget(
      MaterialApp(
        theme: data,
        home: Builder(
          builder: (context) {
            result = ChatTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('falls back to the color scheme without an extension', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    final theme = await themeIn(tester, ThemeData(colorScheme: scheme));
    expect(theme.outgoingBubbleColor, scheme.primary);
    expect(theme.incomingBubbleColor, scheme.surfaceContainerHighest);
    expect(theme.failedColor, scheme.error);
  });

  testWidgets('uses the registered extension', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    final custom = ChatTheme.fallback(
      scheme,
    ).copyWith(outgoingBubbleColor: Colors.pink, bubbleRadius: 6);
    final theme = await themeIn(
      tester,
      ThemeData(colorScheme: scheme, extensions: [custom]),
    );
    expect(theme.outgoingBubbleColor, Colors.pink);
    expect(theme.bubbleRadius, 6);
    expect(theme.incomingBubbleColor, scheme.surfaceContainerHighest);
  });

  test('lerp interpolates colors and sizes', () {
    final a = ChatTheme.fallback(
      const ColorScheme.light(),
    ).copyWith(outgoingBubbleColor: const Color(0xFF000000), avatarSize: 20);
    final b = a.copyWith(
      outgoingBubbleColor: const Color(0xFFFFFFFF),
      avatarSize: 40,
    );
    final mid = a.lerp(b, 0.5);
    expect(mid.avatarSize, 30);
    expect(mid.outgoingBubbleColor.r, closeTo(0.5, 0.01));
    expect(a.lerp(null, 0.5), same(a));
  });
}
