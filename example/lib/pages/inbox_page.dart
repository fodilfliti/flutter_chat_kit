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
