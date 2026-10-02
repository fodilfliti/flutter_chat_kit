import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/widgets/room/date_separator.dart';

/// A centered pill for room events ("Ana joined"), drawn from
/// `ChatTheme.systemMessage`.
class SystemMessageView extends StatelessWidget {
  const SystemMessageView({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = ChatTheme.of(context).systemMessage;
    return Padding(
      padding: style.margin,
      child: ChatChip(
        style: style,
        child: Text(text, style: style.textStyle, textAlign: TextAlign.center),
      ),
    );
  }
}
