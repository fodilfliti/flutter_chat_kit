import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';

/// Delivery state of the current user's message: a clock while pending,
/// ✓ sent, ✓✓ delivered, colored ✓✓ seen, and a tappable ! when failed.
class StatusTicks extends StatelessWidget {
  const StatusTicks({
    required this.status,
    this.color,
    this.seenColor,
    this.failedColor,
    this.size = 14,
    this.onRetry,
    this.strings = const ChatStrings(),
    super.key,
  });

  final MessageStatus status;

  /// Pending, sent and delivered; defaults to `ChatTheme.statusColor`.
  final Color? color;
  final Color? seenColor;
  final Color? failedColor;
  final double size;

  /// Makes the failed icon a retry button.
  final VoidCallback? onRetry;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final base = color ?? theme.statusColor;
    final (icon, tint, label) = switch (status) {
      MessageStatus.pending ||
      MessageStatus.sending => (Icons.schedule, base, strings.statusPending),
      MessageStatus.sent => (Icons.done, base, strings.statusSent),
      MessageStatus.delivered => (
        Icons.done_all,
        base,
        strings.statusDelivered,
      ),
      MessageStatus.seen => (
        Icons.done_all,
        seenColor ?? theme.seenColor,
        strings.statusSeen,
      ),
      MessageStatus.failed => (
        Icons.error_outline,
        failedColor ?? theme.failedColor,
        strings.failedToSend,
      ),
    };
    final retry = status == MessageStatus.failed ? onRetry : null;
    Widget child = Icon(icon, size: size, color: tint);
    if (retry != null) {
      child = InkResponse(onTap: retry, radius: size, child: child);
    }
    return Semantics(
      label: label,
      button: retry != null,
      onTap: retry,
      child: ExcludeSemantics(child: child),
    );
  }
}
