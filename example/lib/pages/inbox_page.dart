import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/i18n/chat_strings.dart';
import 'package:flutter_chat_kit_example/i18n/language_button.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';
import 'package:flutter_chat_kit_example/pages/room_page.dart';
import 'package:flutter_chat_kit_example/style/style_settings.dart';
import 'package:flutter_chat_kit_example/style/style_sheet.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({required this.backend, super.key});

  final ExampleBackend backend;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final InboxController _inbox = widget.backend.kit.inbox();

  @override
  void dispose() {
    _inbox.dispose();
    super.dispose();
  }

  /// For recording the demo again and again: chats, cache, connection,
  /// failures and style go back to their first-launch state. The language
  /// stays as picked. This page is rebuilt with the fresh kit.
  Future<void> _resetDemo() async {
    context.getInheritedWidgetOfExactType<StyleScope>()!.notifier!.resetAll();
    await widget.backend.reset();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.backend.source;
    final t = context.t;
    final strings = chatStringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _inbox,
          builder: (context, _) {
            final unread = _inbox.totalUnread;
            return Text(
              unread == 0 ? t.app.chats : t.app.chatsWithUnread(n: unread),
            );
          },
        ),
        actions: [
          const LanguageButton(),
          const StyleButton(),
          ChatProfileMenuButton(strings: strings),
          LiveMessagesButton(backend: widget.backend),
          ConnectionButton(backend: widget.backend),
          StatefulBuilder(
            builder: (context, setMenuState) => PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'failures' => setMenuState(
                  () => source.randomFailures = !source.randomFailures,
                ),
                _ => unawaited(_resetDemo()),
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'failures',
                  checked: source.randomFailures,
                  child: Text(t.app.randomFailures),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt),
                    title: Text(t.app.resetDemo),
                    subtitle: Text(t.app.resetDemoHint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(kit: widget.backend.kit),
          _FilterChips(inbox: _inbox),
          // Only the chat is styled; rooms opened from the list keep the
          // style and follow the sheet live.
          Expanded(
            child: StyleScope.of(context).chatStyle(
              child: InboxView(
                controller: _inbox,
                strings: strings,
                roomBuilder: (context, room) =>
                    RoomPage(backend: widget.backend, roomId: room.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One inbox, several views of it. For lists shown side by side (tabs),
/// create one controller per list with `kit.inbox(filter: ...)` instead.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.inbox});

  final InboxController inbox;

  @override
  Widget build(BuildContext context) {
    final t = context.t.app.filters;
    final filters = {
      t.all: RoomFilter.all,
      t.chats: RoomFilter.direct,
      t.groups: RoomFilter.groups,
      t.unread: const RoomFilter(unreadOnly: true),
      t.friends: const RoomFilter(labels: {'friends'}),
    };
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 8,
          children: [
            for (final MapEntry(key: label, value: filter) in filters.entries)
              ChoiceChip(
                label: Text(label),
                selected: inbox.filter == filter,
                onSelected: (_) => inbox.setFilter(filter),
              ),
          ],
        ),
      ),
    );
  }
}
