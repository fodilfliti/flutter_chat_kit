import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

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
    final theme = await themeIn(tester, ThemeData(colorScheme: scheme));
    expect(theme.outgoingBubble.color, scheme.primary);
    expect(theme.incomingBubble.color, scheme.surfaceContainerHighest);
    expect(theme.outgoingBubble.textStyle.color, scheme.onPrimary);
    expect(theme.status.failedColor, scheme.error);
    expect(theme.roomTile.divider, BorderSide.none);
    expect(theme.scale, 1);
  });

  testWidgets('uses the registered extension', (tester) async {
    final base = ChatTheme.fallback(scheme);
    final custom = base.copyWith(
      outgoingBubble: base.outgoingBubble.copyWith(
        color: Colors.pink,
        radius: 6,
      ),
    );
    final theme = await themeIn(
      tester,
      ThemeData(colorScheme: scheme, extensions: [custom]),
    );
    expect(theme.outgoingBubble.color, Colors.pink);
    expect(theme.outgoingBubble.radius, 6);
    expect(theme.incomingBubble.color, scheme.surfaceContainerHighest);
  });

  test('bubble picks the side', () {
    final theme = ChatTheme.fallback(scheme);
    expect(theme.bubble(isMine: true), same(theme.outgoingBubble));
    expect(theme.bubble(isMine: false), same(theme.incomingBubble));
  });

  test('withMessageText merges into both bubbles', () {
    final theme = ChatTheme.fallback(
      scheme,
    ).withMessageText(const TextStyle(fontSize: 14, color: Colors.grey));
    for (final bubble in [theme.outgoingBubble, theme.incomingBubble]) {
      expect(bubble.textStyle.fontSize, 14);
      expect(bubble.textStyle.color, Colors.grey);
      expect(bubble.metaStyle.color, isNot(Colors.grey));
    }
  });

  test('mapText rewrites every text style', () {
    final theme = ChatTheme.fallback(
      scheme,
    ).mapText((s) => s.copyWith(fontFamily: 'Cairo'));
    expect(theme.outgoingBubble.textStyle.fontFamily, 'Cairo');
    expect(theme.incomingBubble.metaStyle.fontFamily, 'Cairo');
    expect(theme.composer.hintStyle.fontFamily, 'Cairo');
    expect(theme.roomTile.unreadTimeStyle.fontFamily, 'Cairo');
    expect(theme.appBar.typingStyle.fontFamily, 'Cairo');
    expect(theme.badge.textStyle.fontFamily, 'Cairo');
    expect(theme.captionStyle.fontFamily, 'Cairo');
  });

  test('mapBubbles updates both sides', () {
    final theme = ChatTheme.fallback(
      scheme,
    ).mapBubbles((b) => b.copyWith(radius: 4, shadows: const [BoxShadow()]));
    expect(theme.outgoingBubble.radius, 4);
    expect(theme.incomingBubble.shadows, hasLength(1));
  });

  group('scaled', () {
    final base = ChatTheme.fallback(scheme);

    test('multiplies sizes and fonts', () {
      final big = base.scaled(1.5);
      expect(big.scale, 1.5);
      expect(big.textScale, 1.5);
      expect(big.outgoingBubble.radius, base.outgoingBubble.radius * 1.5);
      expect(big.outgoingBubble.padding, base.outgoingBubble.padding * 1.5);
      expect(
        big.outgoingBubble.textStyle.fontSize,
        base.outgoingBubble.textStyle.fontSize! * 1.5,
      );
      expect(big.roomTile.avatarSize, base.roomTile.avatarSize * 1.5);
      expect(big.composer.buttonSize, base.composer.buttonSize * 1.5);
      expect(big.media.maxWidth, base.media.maxWidth * 1.5);
      expect(big.status.iconSize, base.status.iconSize * 1.5);
      expect(big.size(10), 15);
      expect(big.fontSize(10), 15);
    });

    test('scales text separately', () {
      final t = base.scaled(2, textFactor: 1);
      expect(t.outgoingBubble.radius, base.outgoingBubble.radius * 2);
      expect(
        t.outgoingBubble.textStyle.fontSize,
        base.outgoingBubble.textStyle.fontSize,
      );
      expect(t.textScale, 1);
    });

    test('composes and survives copyWith', () {
      final t = base.scaled(2).scaled(1.5).copyWith(iconColor: Colors.red);
      expect(t.scale, 3);
      expect(t.size(2), 6);
    });

    test('scales tile shapes and dividers', () {
      final tile = ChatRoomTileStyle.card(scheme, radius: 10).scaled(2);
      final shape = tile.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
      final divided = ChatRoomTileStyle.divided(
        scheme,
        side: const BorderSide(width: 1.5),
        indent: 8,
      ).scaled(2);
      expect(divided.divider.width, 3);
      expect(divided.dividerIndent, 16);
    });
  });

  test('tile presets', () {
    final plain = ChatRoomTileStyle.plain(scheme);
    expect(plain.color, isNull);
    expect(plain.divider, BorderSide.none);

    final divided = ChatRoomTileStyle.divided(scheme);
    expect(divided.divider.color, scheme.outlineVariant);
    expect(divided.dividerIndent, isNull);

    final card = ChatRoomTileStyle.card(scheme, elevation: 2);
    expect(card.color, scheme.surfaceContainerLow);
    expect(card.elevation, 2);
    expect(card.margin, isNot(EdgeInsets.zero));
    expect(card.shape, isA<RoundedRectangleBorder>());
  });

  test('lerp interpolates groups and scale', () {
    final a = ChatTheme.fallback(const ColorScheme.light());
    final b = a
        .copyWith(
          outgoingBubble: a.outgoingBubble.copyWith(
            color: const Color(0xFFFFFFFF),
          ),
          messageList: a.messageList.copyWith(avatarSize: 40),
        )
        .scaled(2);
    final start = a.copyWith(
      outgoingBubble: a.outgoingBubble.copyWith(color: const Color(0xFF000000)),
      messageList: a.messageList.copyWith(avatarSize: 20),
    );
    final mid = start.lerp(b, 0.5);
    expect(mid.messageList.avatarSize, 50);
    expect(mid.outgoingBubble.color.r, closeTo(0.5, 0.01));
    expect(mid.scale, 1.5);
    expect(a.lerp(null, 0.5), same(a));
  });

  test('lerp tolerates plain text style overrides', () {
    final a = ChatTheme.fallback(const ColorScheme.light());
    final b = a.copyWith(captionStyle: const TextStyle(fontSize: 20));
    expect(a.captionStyle.inherit, isNot(b.captionStyle.inherit));
    expect(a.lerp(b, 0.25).captionStyle, a.captionStyle);
    expect(a.lerp(b, 0.75).captionStyle, b.captionStyle);
  });
}
