import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';

/// Rounded search field of the inbox with a clear button, styled like the
/// composer input (`ChatComposerStyle`). Debouncing is left to the
/// listener (`InboxController.search` debounces).
class InboxSearchBar extends StatefulWidget {
  const InboxSearchBar({
    required this.onChanged,
    this.initialQuery = '',
    this.padding,
    this.strings = const ChatStrings(),
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String initialQuery;

  /// Defaults to 16 × 8 at the theme scale.
  final EdgeInsetsGeometry? padding;
  final ChatStrings strings;

  @override
  State<InboxSearchBar> createState() => _InboxSearchBarState();
}

class _InboxSearchBarState extends State<InboxSearchBar> {
  late final _text = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final style = theme.composer;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(style.inputRadius),
      borderSide: style.inputBorder,
    );
    return Padding(
      padding:
          widget.padding ??
          EdgeInsets.symmetric(
            horizontal: theme.size(16),
            vertical: theme.size(8),
          ),
      child: TextField(
        controller: _text,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        style: style.textStyle,
        decoration: InputDecoration(
          hintText: widget.strings.searchChats,
          hintStyle: style.hintStyle,
          prefixIcon: Icon(
            Icons.search,
            color: style.iconColor,
            size: style.iconSize,
          ),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close,
                    color: style.iconColor,
                    size: style.iconSize,
                  ),
                  tooltip: widget.strings.clearSearch,
                  onPressed: _clear,
                ),
          filled: true,
          fillColor: style.inputColor,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: theme.size(10)),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
