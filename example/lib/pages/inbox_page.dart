import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/pages/room_page.dart';

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

  void _open(ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomPage(backend: widget.backend, roomId: room.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.backend.source;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _inbox,
          builder: (context, _) {
            final unread = _inbox.totalUnread;
            return Text(unread == 0 ? 'Chats' : 'Chats ($unread)');
          },
        ),
        actions: [
          const ChatProfileMenuButton(strings: exampleStrings),
          ConnectionButton(backend: widget.backend),
          StatefulBuilder(
            builder: (context, setMenuState) => PopupMenuButton<String>(
              onSelected: (_) => setMenuState(
                () => source.randomFailures = !source.randomFailures,
              ),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'failures',
                  checked: source.randomFailures,
                  child: const Text('Random send failures'),
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
          Expanded(
            child: InboxView(
              controller: _inbox,
              onRoomTap: _open,
              strings: exampleStrings,
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

  static const Map<String, RoomFilter> _filters = {
    'All': RoomFilter.all,
    'Chats': RoomFilter.direct,
    'Groups': RoomFilter.groups,
    'Unread': RoomFilter(unreadOnly: true),
    'Friends': RoomFilter(labels: {'friends'}),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 8,
          children: [
            for (final MapEntry(key: label, value: filter) in _filters.entries)
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
