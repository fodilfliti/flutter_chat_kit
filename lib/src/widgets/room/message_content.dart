import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
import 'package:flutter_chat_kit/src/widgets/media/chat_media_scope.dart';
import 'package:flutter_chat_kit/src/widgets/messages/audio_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/deleted_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/file_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/image_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/system_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/text_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/unsupported_message_view.dart';
import 'package:flutter_chat_kit/src/widgets/messages/video_message_view.dart';
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
/// `customBuilders[customType]`, else `customBuilder`, else the unsupported
/// view; without a bubble unless its type is in `bubbledCustomTypes`.
/// System messages render as a centered pill.
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
    Widget? custom;
    var bubbled = false;
    if (m is CustomMessage && !m.isDeleted) {
      custom =
          builders.customBuilders[m.customType]?.call(context, message) ??
          builders.customBuilder?.call(context, message);
      bubbled = builders.bubbledCustomTypes.contains(m.customType);
    }
    final body = custom != null && !bubbled
        ? custom
        : _bubble(context, theme, m, custom: custom);

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
          Padding(
            padding: EdgeInsets.only(top: theme.size(2)),
            child: reactions,
          ),
        if (failed) _FailedNotice(strings: strings, onRetry: onRetry),
      ],
    );
  }

  Widget _bubble(
    BuildContext context,
    ChatTheme theme,
    Message m, {
    Widget? custom,
  }) {
    final style = theme.bubble(isMine: message.isMine);
    final textStyle = style.textStyle;
    final metaStyle = style.metaStyle;
    final meta = _meta(context, theme, m, metaStyle);

    Widget typed(MessageWidgetBuilder? builder, Widget view) =>
        builder?.call(context, message, view) ?? view;

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
          final store = ChatMediaScope.of(context).store;
          final url = file.remoteUrl;
          content = typed(
            builders.fileBuilder,
            FileMessageView(
              file: file,
              textStyle: textStyle,
              metaStyle: metaStyle,
              progress: message.status.isLocal
                  ? message.uploadProgress
                  : url != null && store != null && store.isSupported
                  ? store.downloadProgress(url)
                  : null,
              onTap: onAttachmentTap == null
                  ? null
                  : () => onAttachmentTap!(message, file),
              strings: strings,
              formatters: formatters,
            ),
          );
        case ImageMessage(:final images, caption: final text):
          return _mediaBubble(
            context,
            theme,
            m,
            media: typed(
              builders.imageBuilder,
              ImageMessageView(
                images: images,
                progress: _uploadProgress,
                onTap: onAttachmentTap == null
                    ? null
                    : (i) => onAttachmentTap!(message, images[i]),
                heroTags: [
                  for (var i = 0; i < images.length; i++)
                    heroTagFor(m.localId, i),
                ],
                strings: strings,
              ),
            ),
            caption: text,
          );
        case VideoMessage(:final video, caption: final text):
          return _mediaBubble(
            context,
            theme,
            m,
            media: typed(
              builders.videoBuilder,
              VideoMessageView(
                video: video,
                progress: _uploadProgress,
                onTap: onAttachmentTap == null
                    ? null
                    : () => onAttachmentTap!(message, video),
                heroTag: heroTagFor(m.localId, 0),
                strings: strings,
                formatters: formatters,
              ),
            ),
            caption: text,
          );
        case AudioMessage():
          inlineMeta = false;
          content = typed(
            builders.audioBuilder,
            AudioMessageView(
              message: m,
              color: textStyle.color ?? theme.iconColor,
              activeColor: style.accentColor,
              metaStyle: metaStyle,
              strings: strings,
              formatters: formatters,
            ),
          );
        case CustomMessage() when custom != null:
          inlineMeta = false;
          content = custom;
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
            spacing: theme.size(8),
            children: [content, meta],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              content,
              SizedBox(height: theme.size(2)),
              meta,
            ],
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
                SizedBox(height: theme.size(4)),
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

  /// Hero tag of media [index] of a message, shared with `MediaViewer`.
  static Object heroTagFor(String localId, int index) =>
      'flutter_chat_kit/media/$localId/$index';

  ValueListenable<double?>? get _uploadProgress =>
      message.status.isLocal ? message.uploadProgress : null;

  /// Images and videos run edge to edge in a thin bubble. Without a caption
  /// the time sits on the media in a dark pill. No intrinsic sizing: the
  /// media reserves its aspect ratio before loading.
  Widget _mediaBubble(
    BuildContext context,
    ChatTheme theme,
    Message m, {
    required Widget media,
    required String? caption,
  }) {
    final mine = message.isMine;
    final style = theme.bubble(isMine: mine);
    final textStyle = style.textStyle;
    final metaStyle = style.metaStyle;
    final mediaStyle = theme.media;
    final inset = mediaStyle.inset;
    final radius = MessageBubble.radiusFor(
      message.groupPosition,
      isMine: mine,
      theme: theme,
    );
    final hasCaption = caption != null && caption.trim().isNotEmpty;
    final reply = _reply(context, theme, m, textStyle);
    final overlayStyle = metaStyle.copyWith(
      color: mediaStyle.overlayForegroundColor,
    );

    final mediaStack = Stack(
      children: [
        ClipRRect(
          borderRadius: _shrink(
            radius,
            inset,
            top: reply == null,
            bottom: !hasCaption,
          ),
          child: media,
        ),
        if (!hasCaption)
          PositionedDirectional(
            end: theme.size(6),
            bottom: theme.size(6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mediaStyle.overlayColor,
                borderRadius: BorderRadius.circular(mediaStyle.overlayRadius),
              ),
              child: Padding(
                padding: mediaStyle.overlayPadding,
                child: _meta(
                  context,
                  theme,
                  m,
                  overlayStyle,
                  ticksColor: mediaStyle.overlayForegroundColor,
                ),
              ),
            ),
          ),
      ],
    );
    final child = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: mediaStyle.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reply != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6) * theme.scale,
              child: reply,
            ),
          mediaStack,
          if (hasCaption)
            Padding(
              padding: style.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextMessageView(
                    text: caption,
                    style: textStyle,
                    onLinkTap: onLinkTap,
                    strings: strings,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _meta(context, theme, m, metaStyle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final bubble = MessageBubble(
      message: message,
      padding: EdgeInsets.all(inset),
      clip: true,
      child: child,
    );
    return builders.bubbleBuilder?.call(context, message, bubble) ?? bubble;
  }

  /// [r] inset by [by]; corners away from the bubble edge ([top] or
  /// [bottom] false) are square.
  static BorderRadiusDirectional _shrink(
    BorderRadiusDirectional r,
    double by, {
    required bool top,
    required bool bottom,
  }) {
    Radius less(Radius c, {required bool round}) => round
        ? Radius.elliptical(math.max(0, c.x - by), math.max(0, c.y - by))
        : Radius.zero;
    return BorderRadiusDirectional.only(
      topStart: less(r.topStart, round: top),
      topEnd: less(r.topEnd, round: top),
      bottomStart: less(r.bottomStart, round: bottom),
      bottomEnd: less(r.bottomEnd, round: bottom),
    );
  }

  Widget _meta(
    BuildContext context,
    ChatTheme theme,
    Message m,
    TextStyle metaStyle, {
    Color? ticksColor,
  }) {
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
        color: ticksColor ?? theme.status.color ?? metaStyle.color,
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
      accentColor: theme.bubble(isMine: message.isMine).accentColor,
      onTap: onReplyTap == null ? null : () => onReplyTap!(replyToId),
    );
    return builders.replyPreviewBuilder?.call(context, message, preview) ??
        preview;
  }
}

class _FailedNotice extends StatelessWidget {
  const _FailedNotice({required this.strings, this.onRetry});

  final ChatStrings strings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final failed = theme.status.failedColor;
    final style = theme.incomingBubble.metaStyle.copyWith(color: failed);
    final onRetry = this.onRetry;
    return Padding(
      padding: EdgeInsets.only(top: theme.size(2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: theme.status.iconSize, color: failed),
          SizedBox(width: theme.size(4)),
          Text(strings.failedToSend, style: style),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: failed,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(horizontal: theme.size(6)),
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
