import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for a screen-size package such as `ScaleKitBuilder` or
/// `ScreenUtilInit`: it recomputes a global factor when the screen size
/// changes and returns the same child, so only widgets that depend on the
/// screen rebuild.
class _FakeScaleBuilder extends StatefulWidget {
  const _FakeScaleBuilder({required this.child});

  final Widget child;

  static double factor = 1;

  @override
  State<_FakeScaleBuilder> createState() => _FakeScaleBuilderState();
}

class _FakeScaleBuilderState extends State<_FakeScaleBuilder> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _FakeScaleBuilder.factor = MediaQuery.sizeOf(context).width / 400;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  late ChatTheme seen;

  Widget probe() => Builder(
    builder: (context) {
      seen = ChatTheme.of(context);
      return const SizedBox();
    },
  );

  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData(colorScheme: scheme),
          home: Scaffold(body: child),
        ),
      );

  void setScreen(WidgetTester tester, Size size) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
  }

  group('ChatStyle', () {
    testWidgets('without options keeps the registered theme', (tester) async {
      final registered = ChatTheme.fallback(
        scheme,
      ).mapBubbles((b) => b.copyWith(radius: 3));
      await pump(
        tester,
        ChatStyle(child: probe()),
        theme: ThemeData(colorScheme: scheme, extensions: [registered]),
      );
      expect(identical(seen, registered), isTrue);
    });

    testWidgets('without a registered theme follows the app colors', (
      tester,
    ) async {
      await pump(tester, ChatStyle(child: probe()));
      expect(seen.outgoingBubble.color, scheme.primary);
      expect(seen.scale, 1);
    });

    testWidgets('options apply over the preset', (tester) async {
      await pump(
        tester,
        ChatStyle(
          preset: ChatPreset.whatsApp,
          bubbleRadius: 12,
          child: probe(),
        ),
      );
      expect(seen.outgoingBubble.radius, 12);
      expect(seen.outgoingBubble.tailRadius, 0);
      expect(seen.outgoingBubble.shadows, isNotEmpty);
      expect(seen.outgoingBubble.textStyle.fontSize, 15);
      expect(seen.roomTile.divider, isNot(BorderSide.none));
      expect(seen.status.seenColor, const Color(0xFF53BDEB));
    });

    testWidgets('every simple option lands in the theme', (tester) async {
      const wallpaper = BoxDecoration(color: Color(0xFF123456));
      await pump(
        tester,
        ChatStyle(
          seedColor: Colors.pink,
          bubbleRadius: 9,
          bubbleShadows: true,
          bubbleBorder: true,
          messageStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          fontFamily: 'Cairo',
          tiles: ChatTiles.cards,
          tileRadius: 24,
          squareAvatars: true,
          wallpaper: wallpaper,
          child: probe(),
        ),
      );
      final pink = ColorScheme.fromSeed(seedColor: Colors.pink);
      expect(seen.outgoingBubble.color, pink.primary);
      expect(seen.incomingBubble.radius, 9);
      expect(seen.incomingBubble.shadows, isNotEmpty);
      expect(seen.incomingBubble.border.color, pink.outlineVariant);
      expect(seen.outgoingBubble.textStyle.fontSize, 13);
      expect(seen.outgoingBubble.textStyle.color, Colors.grey);
      expect(seen.captionStyle.fontFamily, 'Cairo');
      expect(seen.roomTile.color, pink.surfaceContainerLow);
      expect(
        seen.roomTile.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      );
      expect(seen.avatar.radius, 10);
      expect(seen.messageList.background, wallpaper);
    });

    testWidgets('customize runs after the options, scale runs last', (
      tester,
    ) async {
      await pump(
        tester,
        ChatStyle(
          bubbleRadius: 12,
          messageStyle: const TextStyle(fontSize: 14),
          customize: (t) =>
              t.copyWith(incomingBubble: t.incomingBubble.copyWith(radius: 30)),
          scale: ChatScale.fixed(2, text: 1.5),
          child: probe(),
        ),
      );
      expect(seen.outgoingBubble.radius, 24);
      expect(seen.incomingBubble.radius, 60);
      expect(seen.outgoingBubble.textStyle.fontSize, 21);
      expect(seen.scale, 2);
      expect(seen.textScale, 1.5);
      expect(seen.size(14), 28);
      expect(seen.fontSize(14), 21);
    });

    testWidgets('nested style inherits and never scales twice', (tester) async {
      late ChatTheme outer;
      await pump(
        tester,
        ChatStyle(
          preset: ChatPreset.minimal,
          scale: ChatScale.fixed(2),
          customize: (t) => t.copyWith(iconColor: Colors.red),
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  outer = context.chatTheme;
                  return const SizedBox();
                },
              ),
              ChatStyle(
                bubbleRadius: 4,
                customize: (t) => t.copyWith(captionStyle: t.captionStyle),
                child: probe(),
              ),
            ],
          ),
        ),
      );
      expect(outer.outgoingBubble.radius, 12);
      expect(seen.outgoingBubble.radius, 8);
      expect(seen.avatar.radius, 20);
      expect(seen.iconColor, Colors.red);
      expect(seen.scale, 2);
    });

    testWidgets('byScreen follows resize and keeps the size on rotation', (
      tester,
    ) async {
      setScreen(tester, const Size(800, 1600));
      final style = ChatStyle(
        scale: ChatScale.byScreen(designWidth: 400, max: 3),
        child: probe(),
      );
      await pump(tester, style);
      expect(seen.scale, 2);

      tester.view.physicalSize = const Size(1600, 800);
      await tester.pump();
      expect(seen.scale, 2);

      tester.view.physicalSize = const Size(600, 1000);
      await tester.pump();
      expect(seen.scale, 1.5);
      expect(seen.outgoingBubble.radius, 18 * 1.5);
    });

    testWidgets('reads a scale package fresh after it updated', (tester) async {
      setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(
        _FakeScaleBuilder(
          child: MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: ChatStyle(
              scale: (_) => ChatScale(_FakeScaleBuilder.factor),
              child: probe(),
            ),
          ),
        ),
      );
      expect(seen.scale, 1);

      tester.view.physicalSize = const Size(600, 800);
      await tester.pump();
      expect(_FakeScaleBuilder.factor, 1.5);
      expect(seen.scale, 1.5);

      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      expect(seen.scale, 2);
    });

    testWidgets('scaleOf reports the nearest style scale', (tester) async {
      final scales = <ChatScale>[];
      Widget read() => Builder(
        builder: (context) {
          scales.add(ChatStyle.scaleOf(context));
          return const SizedBox();
        },
      );
      await pump(
        tester,
        Column(
          children: [
            read(),
            ChatStyle(scale: ChatScale.fixed(1.5), child: read()),
          ],
        ),
      );
      expect(scales, [ChatScale.none, const ChatScale(1.5)]);
    });

    testWidgets('pushed pages keep the style and follow its changes', (
      tester,
    ) async {
      var radius = 5.0;
      late StateSetter setRadius;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: StatefulBuilder(
            builder: (context, setState) {
              setRadius = setState;
              return ChatStyle(
                bubbleRadius: radius,
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => ChatStyle.push<void>(
                      context,
                      (_) => Scaffold(body: probe()),
                    ),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(seen.outgoingBubble.radius, 5);

      setRadius(() => radius = 9);
      await tester.pump();
      await tester.pump();
      expect(seen.outgoingBubble.radius, 9);
    });

    testWidgets('sheets opened inside keep the style', (tester) async {
      await pump(
        tester,
        ChatStyle(
          bubbleRadius: 7,
          scale: ChatScale.fixed(2),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ChatStyle(bubbleBorder: true, child: probe()),
              ),
              child: const Text('sheet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      expect(seen.outgoingBubble.radius, 14);
      expect(seen.outgoingBubble.border.width, 2);
      expect(seen.scale, 2);
    });

    testWidgets('carry without a style returns the page', (tester) async {
      late Widget Function(Widget) keep;
      await pump(
        tester,
        Builder(
          builder: (context) {
            keep = ChatStyle.carry(context);
            return const SizedBox();
          },
        ),
      );
      const page = SizedBox();
      expect(identical(keep(page), page), isTrue);
    });
  });

  group('ChatScale', () {
    test('text defaults to size, times combines, equality', () {
      expect(const ChatScale(1.2).text, 1.2);
      expect(
        const ChatScale(2) * const ChatScale(1.5, text: 2),
        const ChatScale(3, text: 4),
      );
      expect(ChatScale.none.isNone, isTrue);
      expect(const ChatScale(1, text: 1.1).isNone, isFalse);
    });
  });

  group('ChatPreset', () {
    test('every preset builds light and dark themes', () {
      for (final preset in ChatPreset.values) {
        for (final brightness in Brightness.values) {
          final s = ColorScheme.fromSeed(
            seedColor: preset.seedColor ?? Colors.teal,
            brightness: brightness,
          );
          expect(
            preset.build(s, Typography.material2021().englishLike),
            isA<ChatTheme>(),
          );
        }
      }
    });
  });
}
