import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/i18n/strings.g.dart';

/// `booking`: listed in `bubbledCustomTypes`, so the kit draws the bubble,
/// the reply preview, the time and the ticks around it. The content uses
/// the side's bubble colors to stay readable on any theme.
class BookingCard extends StatelessWidget {
  const BookingCard({required this.message, super.key});

  final MessageContext message;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final bubble = theme.bubble(isMine: message.isMine);
    final l10n = MaterialLocalizations.of(context);
    final data = (message.message as CustomMessage).data;
    final at = DateTime.tryParse('${data['at']}')?.toLocal();
    final when = at == null
        ? ''
        : '${l10n.formatMediumDate(at)} · '
              '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';

    Widget row(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(top: theme.size(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: theme.size(16), color: bubble.accentColor),
          SizedBox(width: theme.size(6)),
          Flexible(child: Text(text, style: bubble.textStyle)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '📅 ${data['title'] ?? context.t.custom.booking}',
          style: bubble.textStyle.copyWith(fontWeight: FontWeight.w700),
        ),
        if (when.isNotEmpty) row(Icons.schedule, when),
        if (data['place'] case final String place) row(Icons.place, place),
      ],
    );
  }
}
