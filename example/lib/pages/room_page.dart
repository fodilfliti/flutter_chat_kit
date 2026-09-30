import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/offer/offer_card.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({required this.backend, required this.roomId, super.key});

  final ExampleBackend backend;
  final String roomId;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final ChatRoomController _room = widget.backend.kit.room(widget.roomId);

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ChatRoomView(
      controller: _room,
      strings: exampleStrings,
      header: OfflineBanner(kit: widget.backend.kit),
      builders: ChatBuilders(customBuilders: {offerType: offerBuilder(_room)}),
      extraAttachmentOptions: [offerOption(context, _room)],
      appBar: ChatAppBarOptions(
        actions: [
          IconButton(
            tooltip: 'Make an offer',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => unawaited(showOfferDialog(context, _room)),
          ),
          ConnectionButton(backend: widget.backend),
        ],
        onTitleTap: () => _toast('Open the room details here'),
      ),
      onForward: (messages) =>
          _toast('Forward ${messages.length} message(s): pick a room here'),
    );
  }
}
