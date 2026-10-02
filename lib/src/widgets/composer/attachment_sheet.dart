import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/media/default_pickers.dart';

/// One button of the [AttachmentSheet]. App options (for example "Offer"
/// opening the app's own form, then `sendCustom`) use [onSelected].
///
/// ```dart
/// ChatRoomView(
///   controller: room,
///   extraAttachmentOptions: [
///     AttachmentOption(
///       icon: Icons.local_offer_outlined,
///       label: 'Offer',
///       onSelected: () => showOfferForm(context, room),
///     ),
///   ],
/// )
/// ```
@immutable
class AttachmentOption {
  /// A button with [icon] and [label]. Give [onSelected] for app options;
  /// [source] is for the built-in pickers.
  const AttachmentOption({
    required this.icon,
    required this.label,
    this.onSelected,
    this.source,
    this.color,
  });

  /// Icon inside the round button.
  final IconData icon;

  /// Text under the button.
  final String label;

  /// Called after the sheet closes.
  final VoidCallback? onSelected;

  /// Set for the built-in options; the composer picks from it.
  final AttachmentSource? source;

  /// Background of the round button. Defaults to the composer's send
  /// button color.
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
  /// A grid of [options]. Usually opened with [show].
  const AttachmentSheet({required this.options, super.key});

  /// The buttons, in order.
  final List<AttachmentOption> options;

  /// Opens the sheet over [context] and returns the tapped option, or null
  /// when dismissed.
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
    final composer = theme.composer;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16) * theme.scale,
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: theme.size(12),
          runSpacing: theme.size(16),
          children: [
            for (final option in options)
              SizedBox(
                width: theme.size(76),
                child: InkWell(
                  borderRadius: BorderRadius.circular(theme.size(12)),
                  onTap: () => Navigator.of(context).pop(option),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.size(6)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: theme.size(26),
                          backgroundColor:
                              option.color ?? composer.sendButtonColor,
                          child: Icon(
                            option.icon,
                            color: composer.sendIconColor,
                            size: composer.iconSize,
                          ),
                        ),
                        SizedBox(height: theme.size(6)),
                        Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.captionStyle,
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
