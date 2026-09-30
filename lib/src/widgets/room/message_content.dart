import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/widgets/common/message_snippet.dart';
import 'package:flutter_chat_kit/src/widgets/messages/deleted_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/file_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/system_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/text_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/unsupported_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_bubble.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_meta.dart';
import 'package:flutter_chat_kit/src/widgets/room/reactions_bar.dart';
import 'package:flutter_chat_kit/src/widgets/room/reply_preview.dart';
import 'package:flutter_chat_kit/src/widgets/room/status_ticks.dart';

/// Called with the attachment of a tapped file (or media) message.
typedef AttachmentTapCallback =
    void Function(MessageContext message, Attachment attachment);

/// The default rendering of one message: the bubble with the reply preview,
/// the content and the time / status line, then reactions and the failed
/// notice.
///
/// Resolution order: `ChatBuilders.bubbleBuilder` gets the default bubble,
/// which holds the per-type builder's widget (`textBuilder`, `fileBuilder`,
/// …) or the default view. A `CustomMessage` renders through
/// `customBuilders[customType]` without a bubble, else the unsupported
/// view. System messages render as a centered pill.
class MessageContent extends StatelessWidget {
  const MessageContent({
    required this.message,
    this.builders = const ChatBuilders(),
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.showReactions = true,
    this.onReplyTap,
    this.onReactionTap,
    this.onRetry,
    this.onLinkTap,
    this.onAttachmentTap,
    super.key,
  });

  final MessageContext message;
  final ChatBuilders builders;
  final ChatStrings strings;
  final ChatFormatters formatters;
  final bool showReactions;

  /// Called with the id of the quoted message.
  final ValueChanged<String>? onReplyTap;
  final ValueChanged<String>? onReactionTap;
  final VoidCallback? onRetry;
  final LinkTapCallback? onLinkTap;
  final AttachmentTapCallback? onAttachmentTap;

  @override
  Widget build(BuildContext context) {
    final m = message.message;
    if (m is SystemMessage) {
      final view = SystemMessageView(text: strings.system(m.code, m.args));
      return builders.systemBuilder?.call(context, message, view) ?? view;
    }
    final theme = ChatTheme.of(context);
    final custom = m is CustomMessage && !m.isDeleted
        ? builders.customBuilders[m.customType]
        : null;
    final body = custom != null
        ? custom(context, message)
        : _bubble(context, theme, m);

    final hasReactions =
        showReactions &&
        !m.isDeleted &&
        m.reactions.values.any((users) => users.isNotEmpty);
    final failed = message.isMine && message.status == MessageStatus.failed;
    if (!hasReactions && !failed) return body;

    Widget? reactions;
    if (hasReactions) {
      final bar = ReactionsBar(
        reactions: m.reactions,
        currentUserId: message.currentUserId,
        onToggle: onReactionTap,
        strings: strings,
      );
      reactions = builders.reactionsBuilder?.call(context, message, bar) ?? bar;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: message.isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        body,
        if (reactions != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: reactions),
        if (failed) _FailedNotice(strings: strings, onRetry: onRetry),
      ],
    );
  }

  Widget _bubble(BuildContext context, ChatTheme theme, Message m) {
    final mine = message.isMine;
    final textStyle = mine ? theme.outgoingTextStyle : theme.incomingTextStyle;
    final metaStyle = mine ? theme.outgoingMetaStyle : theme.incomingMetaStyle;
    final meta = _meta(context, theme, m, metaStyle);

    Widget typed(MessageWidgetBuilder? builder, Widget view) =>
        builder?.call(context, message, view) ?? view;
    Widget caption(String? text) => text == null || text.trim().isEmpty
        ? const SizedBox.shrink()
        : TextMessageView(
            text: text,
            style: textStyle,
            onLinkTap: onLinkTap,
            strings: strings,
          );

    final Widget content;
    var inlineMeta = true;
    if (m.isDeleted) {
      content = typed(
        builders.deletedBuilder,
        DeletedMessageView(label: strings.messageDeleted, style: metaStyle),
      );
    } else {
      switch (m) {
        case TextMessage(:final text):
          content = typed(
            builders.textBuilder,
            TextMessageView(
              text: text,
              style: textStyle,
              onLinkTap: onLinkTap,
              strings: strings,
            ),
          );
        case FileMessage(:final file):
          inlineMeta = false;
          content = typed(
            builders.fileBuilder,
            FileMessageView(
              file: file,
              textStyle: textStyle,
              metaStyle: metaStyle,
              progress: message.status.isLocal ? message.uploadProgress : null,
              onTap: onAttachmentTap == null
                  ? null
                  : () => onAttachmentTap!(message, file),
              strings: strings,
              formatters: formatters,
            ),
          );
        case ImageMessage(:final images, caption: final text):
          inlineMeta = false;
          content = typed(
            builders.imageBuilder,
            _MediaPlaceholder(
              icon: Icons.photo_outlined,
              label: strings.photos(images.length),
              style: textStyle,
              caption: caption(text),
            ),
          );
        case VideoMessage(caption: final text):
          inlineMeta = false;
          content = typed(
            builders.videoBuilder,
            _MediaPlaceholder(
              icon: Icons.videocam_outlined,
              label: strings.video,
              style: textStyle,
              caption: caption(text),
            ),
          );
        case AudioMessage():
          inlineMeta = false;
          content = typed(
            builders.audioBuilder,
            _MediaPlaceholder(
              icon: Icons.mic_none,
              label: strings.voice,
              style: textStyle,
            ),
          );
        case CustomMessage():
          content = typed(
            builders.unsupportedBuilder,
            UnsupportedMessageView(
              label: strings.unsupportedMessage,
              style: metaStyle,
            ),
          );
        case SystemMessage():
          content = const SizedBox.shrink();
      }
    }

    final Widget laidOut = inlineMeta
        ? Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [content, meta],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [content, const SizedBox(height: 2), meta],
          );

    final reply = _reply(context, theme, m, textStyle);
    final inner = reply == null
        ? laidOut
        : IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                reply,
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: laidOut,
                ),
              ],
            ),
          );
    final bubble = MessageBubble(message: message, child: inner);
    return builders.bubbleBuilder?.call(context, message, bubble) ?? bubble;
  }

  Widget _meta(
    BuildContext context,
    ChatTheme theme,
    Message m,
    TextStyle metaStyle,
  ) {
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    Widget time = Text(
      formatters.formatTime(m.createdAt, locale: locale),
      style: metaStyle,
    );
    time = builders.timestampBuilder?.call(context, message, time) ?? time;
    Widget? ticks;
    if (message.isMine) {
      ticks = StatusTicks(
        status: message.status,
        color: metaStyle.color,
        seenColor: theme.seenColor,
        failedColor: theme.failedColor,
        onRetry: onRetry,
        strings: strings,
      );
      ticks = builders.statusBuilder?.call(context, message, ticks) ?? ticks;
    }
    return MessageMeta(
      time: time,
      edited: m.isEdited && !m.isDeleted
          ? Text(strings.edited, style: metaStyle)
          : null,
      ticks: ticks,
    );
  }

  Widget? _reply(
    BuildContext context,
    ChatTheme theme,
    Message m,
    TextStyle textStyle,
  ) {
    final replyToId = m.replyToId;
    if (replyToId == null || m.isDeleted) return null;
    final quoted = message.repliedTo;
    final title = quoted == null
        ? null
        : quoted.authorId == message.currentUserId
        ? strings.you
        : message.repliedToAuthor?.name;
    final preview = ReplyPreview(
      title: title,
      snippet: quoted == null
          ? strings.replyUnavailable
          : messageSnippet(quoted, strings),
      textStyle: textStyle,
      accentColor: message.isMine ? textStyle.color : theme.replyAccentColor,
      onTap: onReplyTap == null ? null : () => onReplyTap!(replyToId),
    );
    return builders.replyPreviewBuilder?.call(context, message, preview) ??
        preview;
  }
}

/// Icon and label for media messages until the media views render them.
class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    required this.style,
    this.caption,
  });

  final IconData icon;
  final String label;
  final TextStyle style;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: style.color, size: 20),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: style)),
          ],
        ),
        ?caption,
      ],
    );
  }
}

class _FailedNotice extends StatelessWidget {
  const _FailedNotice({required this.strings, this.onRetry});

  final ChatStrings strings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final style = theme.incomingMetaStyle.copyWith(color: theme.failedColor);
    final onRetry = this.onRetry;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: theme.failedColor),
          const SizedBox(width: 4),
          Text(strings.failedToSend, style: style),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: theme.failedColor,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                strings.retry,
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
