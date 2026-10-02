import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controllers/harness.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

  RoomContext room({int unread = 0}) => RoomContext(
    room: ChatRoom(
      id: 'r1',
      updatedAt: t0,
      title: 'Team',
      unreadCount: unread,
      lastMessage: msg(1),
    ),
    currentUserId: 'me',
    index: 0,
  );

  Future<void> show(WidgetTester tester, ChatTheme chat, {int unread = 0}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, extensions: [chat]),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: RoomTile(
              room: room(unread: unread),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder tileMaterial() => find
      .descendant(of: find.byType(RoomTile), matching: find.byType(Material))
      .first;

  Finder dividerLine(Color color) => find.descendant(
    of: find.byType(RoomTile),
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == color,
    ),
  );

  testWidgets('plain tiles are transparent without a line', (tester) async {
    final chat = ChatTheme.fallback(scheme);
    await show(tester, chat);
    final material = tester.widget<Material>(tileMaterial());
    expect(material.type, MaterialType.transparency);
    expect(dividerLine(scheme.outlineVariant), findsNothing);
  });

  testWidgets('divided tiles draw a bottom line from the text start', (
    tester,
  ) async {
    final base = ChatTheme.fallback(scheme);
    final chat = base.copyWith(
      roomTile: ChatRoomTileStyle.divided(
        scheme,
        side: const BorderSide(color: Colors.red, width: 2),
      ),
    );
    await show(tester, chat);
    final line = dividerLine(Colors.red);
    expect(line, findsOneWidget);
    expect(tester.getSize(line).height, 2);
    final style = chat.roomTile;
    expect(
      tester.getTopLeft(line).dx,
      style.padding.left + style.avatarSize + style.gap,
    );
  });

  testWidgets('card tiles get a shape, color and margin', (tester) async {
    final chat = ChatTheme.fallback(scheme).copyWith(
      roomTile: ChatRoomTileStyle.card(
        scheme,
        radius: 20,
        color: Colors.amber,
        margin: const EdgeInsets.all(10),
      ),
    );
    await show(tester, chat);
    final material = tester.widget<Material>(tileMaterial());
    expect(material.color, Colors.amber);
    expect(
      material.shape,
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
    expect(tester.getTopLeft(tileMaterial()), const Offset(10, 10));
  });

  testWidgets('scale reaches the avatar, fonts and badge', (tester) async {
    final base = ChatTheme.fallback(scheme);
    await show(tester, base.scaled(1.5), unread: 3);
    final avatar = find.byType(ChatAvatar).first;
    expect(tester.getSize(avatar).width, base.roomTile.avatarSize * 1.5);
    final title = tester.widget<Text>(find.text('Team'));
    expect(
      title.style?.fontSize,
      base.roomTile.unreadTitleStyle.fontSize! * 1.5,
    );
    expect(
      tester.getSize(find.byType(ChatUnreadBadge)).height,
      base.badge.size * 1.5,
    );
  });
}
