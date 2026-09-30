import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/media/default_pickers.dart';

/// One button of the [AttachmentSheet]. App options (for example "Offer"
/// opening the app's own form, then `sendCustom`) use [onSelected].
@immutable
class AttachmentOption {
  const AttachmentOption({
    required this.icon,
    required this.label,
    this.onSelected,
    this.source,
    this.color,
  });

  final IconData icon;
  final String label;

  /// Called after the sheet closes.
  final VoidCallback? onSelected;

  /// Set for the built-in options; the composer picks from it.
  final AttachmentSource? source;
  final Color? color;

  /// Camera, gallery, video and file, labeled from [strings].
  static List<AttachmentOption> defaults(ChatStrings strings) => [
    AttachmentOption(
      icon: Icons.photo_camera_outlined,
      label: strings.camera,
      source: AttachmentSource.camera,
      color: const Color(0xFFE91E63),
    ),
    AttachmentOption(
      icon: Icons.photo_library_outlined,
      label: strings.gallery,
      source: AttachmentSource.gallery,
      color: const Color(0xFF7E57C2),
    ),
    AttachmentOption(
      icon: Icons.videocam_outlined,
      label: strings.video,
      source: AttachmentSource.video,
      color: const Color(0xFFEF6C00),
    ),
    AttachmentOption(
      icon: Icons.insert_drive_file_outlined,
      label: strings.file,
      source: AttachmentSource.file,
      color: const Color(0xFF1E88E5),
    ),
  ];
}

/// A bottom sheet grid of [options]; [show] returns the chosen one.
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({required this.options, super.key});

  final List<AttachmentOption> options;

  static Future<AttachmentOption?> show(
    BuildContext context, {
    required List<AttachmentOption> options,
  }) {
    return showModalBottomSheet<AttachmentOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => AttachmentSheet(options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final option in options)
              SizedBox(
                width: 76,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              option.color ?? theme.sendButtonColor,
                          child: Icon(option.icon, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.roomSubtitleStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
