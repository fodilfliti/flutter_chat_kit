import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_formatters.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';

/// A file attachment: type icon, name and size, with an upload progress
/// ring while it uploads.
class FileMessageView extends StatelessWidget {
  const FileMessageView({
    required this.file,
    required this.textStyle,
    required this.metaStyle,
    this.progress,
    this.onTap,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final Attachment file;
  final TextStyle textStyle;

  /// Style of the size line.
  final TextStyle metaStyle;

  /// Upload fraction 0..1, or null when not uploading.
  final ValueListenable<double?>? progress;
  final VoidCallback? onTap;
  final ChatStrings strings;
  final ChatFormatters formatters;

  static const _byExtension = <String, IconData>{
    'pdf': Icons.picture_as_pdf_outlined,
    'doc': Icons.description_outlined,
    'docx': Icons.description_outlined,
    'odt': Icons.description_outlined,
    'rtf': Icons.description_outlined,
    'txt': Icons.description_outlined,
    'md': Icons.description_outlined,
    'xls': Icons.table_chart_outlined,
    'xlsx': Icons.table_chart_outlined,
    'ods': Icons.table_chart_outlined,
    'csv': Icons.table_chart_outlined,
    'ppt': Icons.slideshow_outlined,
    'pptx': Icons.slideshow_outlined,
    'odp': Icons.slideshow_outlined,
    'zip': Icons.folder_zip_outlined,
    'rar': Icons.folder_zip_outlined,
    '7z': Icons.folder_zip_outlined,
    'tar': Icons.folder_zip_outlined,
    'gz': Icons.folder_zip_outlined,
    'apk': Icons.android,
  };

  /// Icon for the file's extension, else for its MIME type.
  static IconData iconFor(Attachment file) {
    final name = file.name ?? file.source ?? '';
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      final icon = _byExtension[name.substring(dot + 1).toLowerCase()];
      if (icon != null) return icon;
    }
    return switch (file.kind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.video => Icons.video_file_outlined,
      AttachmentKind.audio => Icons.audio_file_outlined,
      AttachmentKind.file => Icons.insert_drive_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final color = textStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final size = file.size;
    final icon = Icon(iconFor(file), color: color, size: theme.size(24));
    final progress = this.progress;
    final leading = SizedBox.square(
      dimension: theme.size(44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: progress == null
            ? Center(child: icon)
            : ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (context, value, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    if (value != null)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 2.5,
                          color: color,
                        ),
                      ),
                    child!,
                  ],
                ),
                child: icon,
              ),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.size(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: theme.size(10)),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name ?? strings.file,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (size != null)
                  Text(formatters.formatFileSize(size), style: metaStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
