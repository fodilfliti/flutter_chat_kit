import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// A quoted message: accent bar, author and a one-line snippet. Used inside
/// bubbles (tap jumps to the original) and above the composer ([onClose]).
class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    required this.snippet,
    this.title,
    this.textStyle,
    this.accentColor,
    this.onTap,
    this.onClose,
    this.closeTooltip,
    super.key,
  });

  final String snippet;

  /// Usually the quoted author's name.
  final String? title;

  /// Snippet style; defaults to the incoming bubble text.
  final TextStyle? textStyle;

  /// Defaults to `ChatTheme.replyAccentColor`.
  final Color? accentColor;
  final VoidCallback? onTap;

  /// Shows a close button when set.
  final VoidCallback? onClose;
  final String? closeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final accent = accentColor ?? theme.replyAccentColor;
    final style = textStyle ?? theme.incomingTextStyle;
    final title = this.title;
    final onClose = this.onClose;
    final body = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: (style.fontSize ?? 16) * 0.85,
              ),
            ),
          Text(
            snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: accent, width: 3),
              ),
            ),
            child: onClose == null
                ? body
                : Row(
                    children: [
                      Expanded(child: body),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: closeTooltip,
                        onPressed: onClose,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
