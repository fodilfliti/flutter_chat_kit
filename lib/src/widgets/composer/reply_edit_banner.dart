import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/widgets/common/message_snippet.dart';
import 'package:flutter_chat_kit/src/widgets/room/reply_preview.dart';

/// Above the composer input: the message being replied to (author and
/// snippet) or edited (`ChatStrings.editing`), with a close button.
class ReplyEditBanner extends StatelessWidget {
  const ReplyEditBanner({
    required this.message,
    required this.isEditing,
    required this.onClose,
    this.authorName,
    this.strings = const ChatStrings(),
    super.key,
  });

  final Message message;
  final bool isEditing;
  final VoidCallback onClose;

  /// Shown as the reply title; the current user's messages use
  /// `ChatStrings.you`.
  final String? authorName;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 0) * theme.scale,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: theme.size(4),
              end: theme.size(8),
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.reply,
              color: theme.replyPreview.accentColor,
              size: theme.size(20),
            ),
          ),
          Expanded(
            child: ReplyPreview(
              title: isEditing ? strings.editing : authorName,
              snippet: messageSnippet(message, strings),
              textStyle: theme.composer.textStyle,
              onClose: onClose,
              closeTooltip: strings.cancel,
            ),
          ),
        ],
      ),
    );
  }
}
