import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';

/// Rounded search field of the inbox with a clear button. Debouncing is
/// left to the listener (`InboxController.search` debounces).
class InboxSearchBar extends StatefulWidget {
  const InboxSearchBar({
    required this.onChanged,
    this.initialQuery = '',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.strings = const ChatStrings(),
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String initialQuery;
  final EdgeInsetsGeometry padding;
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
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _text,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        style: theme.composerTextStyle,
        decoration: InputDecoration(
          hintText: widget.strings.searchChats,
          hintStyle: theme.composerHintStyle,
          prefixIcon: Icon(Icons.search, color: theme.iconColor),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: theme.iconColor),
                  tooltip: widget.strings.clearSearch,
                  onPressed: _clear,
                ),
          filled: true,
          fillColor: theme.composerInputColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
