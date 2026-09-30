import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_styles.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Reaction chips with counts, most used first; the current user's
/// reactions are highlighted and tapping a chip toggles it.
class ReactionsBar extends StatelessWidget {
  const ReactionsBar({
    required this.reactions,
    required this.currentUserId,
    this.onToggle,
    this.strings = const ChatStrings(),
    super.key,
  });

  /// Emoji to the ids of users who reacted with it.
  final Map<String, Set<String>> reactions;
  final String currentUserId;
  final ValueChanged<String>? onToggle;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final entries = [
      for (final e in reactions.entries)
        if (e.value.isNotEmpty) e,
    ]..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (entries.isEmpty) return const SizedBox.shrink();
    final style = theme.reactions;
    return Wrap(
      spacing: style.spacing,
      runSpacing: style.spacing,
      children: [
        for (final e in entries)
          _chip(
            theme,
            style,
            e.key,
            e.value.length,
            mine: e.value.contains(currentUserId),
          ),
      ],
    );
  }

  Widget _chip(
    ChatTheme theme,
    ChatReactionStyle style,
    String emoji,
    int count, {
    required bool mine,
  }) {
    final onToggle = this.onToggle;
    final onTap = onToggle == null ? null : () => onToggle(emoji);
    return Semantics(
      label: strings.reaction(emoji, count),
      selected: mine,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: mine ? style.mineColor : style.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.radius),
            side: mine ? style.mineBorder : style.border,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: style.padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: style.textStyle.copyWith(fontSize: style.emojiSize),
                  ),
                  SizedBox(width: theme.size(4)),
                  Text(count.toString(), style: style.textStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
