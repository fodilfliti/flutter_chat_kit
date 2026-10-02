import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/widgets/common/message_snippet.dart';

/// Replaces the room app bar while messages are selected: close, count,
/// copy, forward (when [onForward] is set) and delete (when every selected
/// message is the current user's).
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    required this.controller,
    this.onForward,
    this.actions = const [],
    this.backgroundColor,
    this.strings = const ChatStrings(),
    super.key,
  });

  final ChatRoomController controller;

  /// Receives the selected messages, oldest first. The selection is cleared
  /// afterwards; the app picks the target room.
  final ValueChanged<List<Message>>? onForward;

  /// Extra actions after the default ones.
  final List<Widget> actions;
  final Color? backgroundColor;
  final ChatStrings strings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// The loaded selected messages, oldest first.
  static List<Message> selectedMessages(ChatRoomController controller) {
    final ids = controller.selectedIds;
    return [
      for (final m in controller.messages.reversed)
        if (ids.contains(m.localId)) m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = selectedMessages(controller);
        final me = controller.currentUserId;
        final texts = [for (final m in selected) ?copyableText(m)];
        final canDelete =
            selected.isNotEmpty &&
            selected.every(
              (m) => m.authorId == me && !m.isDeleted && m is! SystemMessage,
            );
        final forward = onForward;
        final canForward =
            forward != null &&
            selected.isNotEmpty &&
            selected.every(
              (m) => !m.isDeleted && !m.status.isLocal && m is! SystemMessage,
            );
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: backgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: strings.cancel,
            onPressed: controller.clearSelection,
          ),
          title: Text(strings.selectedCount(controller.selectedIds.length)),
          actions: [
            if (texts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: strings.copy,
                onPressed: () => _copy(context, texts.join('\n')),
              ),
            if (canForward)
              IconButton(
                icon: const Icon(Icons.shortcut),
                tooltip: strings.forward,
                onPressed: () {
                  forward(selected);
                  controller.clearSelection();
                },
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: strings.delete,
                onPressed: () => _delete(selected),
              ),
            ...actions,
          ],
        );
      },
    );
  }

  void _copy(BuildContext context, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(strings.copied)));
    controller.clearSelection();
  }

  void _delete(List<Message> messages) {
    for (final m in messages) {
      unawaited(
        m.status.isLocal
            ? controller.discard(m.localId)
            : controller.delete(m.id),
      );
    }
    controller.clearSelection();
  }
}
