import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/composer_controller.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/widgets/common/message_snippet.dart';

/// The long-press menu of a message: a row of quick reactions and the
/// actions list.
class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({
    required this.actions,
    this.quickReactions = const [],
    this.selectedReactions = const {},
    this.onReact,
    this.strings = const ChatStrings(),
    super.key,
  });

  final List<MessageAction> actions;
  final List<String> quickReactions;

  /// Emoji the current user already reacted with.
  final Set<String> selectedReactions;

  /// Quick reactions only show when set.
  final ValueChanged<String>? onReact;
  final ChatStrings strings;

  /// Shows the sheet as a modal bottom sheet. Tapping an action or a
  /// reaction closes it first.
  static Future<void> show(
    BuildContext context, {
    required List<MessageAction> actions,
    List<String> quickReactions = const [],
    Set<String> selectedReactions = const {},
    ValueChanged<String>? onReact,
    ChatStrings strings = const ChatStrings(),
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MessageActionsSheet(
        actions: actions,
        quickReactions: quickReactions,
        selectedReactions: selectedReactions,
        onReact: onReact,
        strings: strings,
      ),
    );
  }

  /// The default actions for [message], filtered by what it allows. An
  /// action is left out when its callback is null.
  ///
  /// - reply: confirmed, not deleted
  /// - copy: has text or a caption
  /// - edit: own confirmed text, image or video message
  /// - retry: own failed message
  /// - delete: own message (a failed or pending one is discarded)
  /// - select: starts multi-selection
  static List<MessageAction> defaults({
    required MessageContext message,
    ChatStrings strings = const ChatStrings(),
    VoidCallback? onReply,
    VoidCallback? onCopy,
    VoidCallback? onEdit,
    VoidCallback? onRetry,
    VoidCallback? onDelete,
    VoidCallback? onSelect,
  }) {
    final m = message.message;
    if (m is SystemMessage || m.isDeleted) return const [];
    final mine = message.isMine;
    final local = m.status.isLocal;
    return [
      if (onReply != null && !local)
        MessageAction(
          id: MessageAction.replyId,
          label: strings.reply,
          icon: Icons.reply,
          onTap: onReply,
        ),
      if (onCopy != null && copyableText(m) != null)
        MessageAction(
          id: MessageAction.copyId,
          label: strings.copy,
          icon: Icons.copy,
          onTap: onCopy,
        ),
      if (onEdit != null &&
          message.isSentByMe &&
          !local &&
          ComposerController.canEdit(m))
        MessageAction(
          id: MessageAction.editId,
          label: strings.edit,
          icon: Icons.edit_outlined,
          onTap: onEdit,
        ),
      if (onRetry != null && mine && m.status == MessageStatus.failed)
        MessageAction(
          id: MessageAction.retryId,
          label: strings.retry,
          icon: Icons.refresh,
          onTap: onRetry,
        ),
      if (onSelect != null)
        MessageAction(
          id: MessageAction.selectId,
          label: strings.select,
          icon: Icons.check_circle_outline,
          onTap: onSelect,
        ),
      if (onDelete != null && mine)
        MessageAction(
          id: MessageAction.deleteId,
          label: strings.delete,
          icon: Icons.delete_outline,
          onTap: onDelete,
          isDestructive: true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final onReact = this.onReact;
    return Semantics(
      label: strings.messageOptions,
      container: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onReact != null && quickReactions.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 8) * theme.scale,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in quickReactions)
                        _reaction(context, theme, emoji, onReact),
                    ],
                  ),
                ),
              for (final action in actions) _action(context, theme, action),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reaction(
    BuildContext context,
    ChatTheme theme,
    String emoji,
    ValueChanged<String> onReact,
  ) {
    final selected = selectedReactions.contains(emoji);
    return Tooltip(
      message: strings.reactWith(emoji),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? theme.reactions.mineColor : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              onReact(emoji);
            },
            child: Padding(
              padding: EdgeInsets.all(theme.size(8)),
              child: Text(
                emoji,
                style: TextStyle(fontSize: theme.fontSize(26)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, ChatTheme theme, MessageAction action) {
    final color = action.isDestructive ? theme.status.failedColor : null;
    return ListTile(
      leading: Icon(
        action.icon,
        color: color ?? theme.iconColor,
        size: theme.size(24),
      ),
      title: Text(action.label, style: TextStyle(color: color)),
      onTap: () {
        Navigator.of(context).pop();
        final result = action.onTap();
        if (result is Future<void>) unawaited(result);
      },
    );
  }
}
