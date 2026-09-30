import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/widgets/messages/file_message_view.dart';

/// Files picked but not sent yet: a row of thumbnails, each with a remove
/// button.
class StagedAttachments extends StatelessWidget {
  const StagedAttachments({
    required this.files,
    required this.onRemove,
    this.size = 64,
    this.strings = const ChatStrings(),
    super.key,
  });

  final List<Attachment> files;
  final ValueChanged<Attachment> onRemove;
  final double size;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size + 12,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Thumb(
          file: files[i],
          size: size,
          onRemove: () => onRemove(files[i]),
          removeLabel: strings.removeAttachment,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.file,
    required this.size,
    required this.onRemove,
    required this.removeLabel,
  });

  final Attachment file;
  final double size;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final local = file.localPath;
    Widget preview;
    if (file.kind == AttachmentKind.image && local != null && !kIsWeb) {
      preview = Image.file(
        File(local),
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        errorBuilder: (_, _, _) => _icon(theme, Icons.broken_image_outlined),
      );
    } else if (file.kind == AttachmentKind.image && local != null) {
      preview = Image.network(
        local,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _icon(theme, Icons.broken_image_outlined),
      );
    } else if (file.kind == AttachmentKind.video) {
      preview = _icon(theme, Icons.videocam_outlined);
    } else {
      preview = Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FileMessageView.iconFor(file), color: theme.iconColor),
            const SizedBox(height: 2),
            Text(
              file.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.roomTimeStyle,
            ),
          ],
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(color: theme.composerInputColor, child: preview),
          ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: Tooltip(
                message: removeLabel,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(ChatTheme theme, IconData icon) =>
      Center(child: Icon(icon, color: theme.iconColor));
}
