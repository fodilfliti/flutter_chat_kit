import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/custom/booking_card.dart';
import 'package:flutter_chat_pro_example/custom/offer_cards.dart';
import 'package:flutter_chat_pro_example/i18n/strings.g.dart';

/// One type, several cards: `data['variant']` picks the widget.
const offerType = 'offer';

/// Drawn inside the regular bubble, with its time and ticks.
const bookingType = 'booking';

const productVariant = 'product';
const quoteVariant = 'quote';

/// Custom message rendering for a room.
///
/// - `booking` goes through [ChatBuilders.customBuilders] and
///   [ChatBuilders.bubbledCustomTypes], so the kit wraps it in a bubble.
/// - `offer` goes through the [ChatBuilders.customBuilder] resolver, which
///   picks a card from the message data and returns null for variants this
///   app version does not know (they show as unsupported).
ChatBuilders exampleBuilders(ChatRoomController room) {
  void reply(MessageContext m, String text) =>
      unawaited(room.sendText(text, replyToId: m.message.id));

  return ChatBuilders(
    customBuilders: {bookingType: (context, m) => BookingCard(message: m)},
    bubbledCustomTypes: const {bookingType},
    customBuilder: (context, m) {
      final message = m.message as CustomMessage;
      if (message.customType != offerType) return null;
      final t = context.t.custom;
      return switch (message.data['variant'] ?? productVariant) {
        productVariant => ProductOfferCard(
          message: m,
          onRespond: (accepted) => reply(m, accepted ? t.deal : t.noThanks),
        ),
        quoteVariant => QuoteCard(
          message: m,
          onAccept: () => reply(m, t.quoteAccepted),
        ),
        _ => null,
      };
    },
  );
}

/// Inbox and reply preview text for custom messages.
String? customPreview(
  Translations t,
  String customType,
  Map<String, Object?> data,
) {
  final title = '${data['title'] ?? ''}';
  return switch (customType) {
    offerType when data['variant'] == quoteVariant => t.custom.quotePreview(
      title: title,
      amount: formatAmount(quoteTotal(data), data),
    ),
    offerType => t.custom.offerPreview(
      title: title,
      amount: formatAmount(data['amount'], data),
    ),
    bookingType => '📅 $title',
    _ => null,
  };
}

String formatAmount(Object? amount, Map<String, Object?> data) =>
    '$amount ${data['currency'] ?? 'USD'}';

num quoteTotal(Map<String, Object?> data) {
  final items = data['items'];
  if (items is! List) return 0;
  return items.fold<num>(
    0,
    (sum, item) =>
        sum +
        (item is Map && item['amount'] is num ? item['amount'] as num : 0),
  );
}

/// The attachment sheet entries for the custom messages.
List<AttachmentOption> customOptions(
  BuildContext context,
  ChatRoomController room,
) {
  final t = context.t.custom;
  return [
    AttachmentOption(
      icon: Icons.local_offer_outlined,
      label: t.offer,
      onSelected: () => unawaited(showOfferDialog(context, room)),
    ),
    AttachmentOption(
      icon: Icons.request_quote_outlined,
      label: t.quote,
      onSelected: () => unawaited(sendSampleQuote(context, room)),
    ),
    AttachmentOption(
      icon: Icons.event_outlined,
      label: t.booking,
      onSelected: () => unawaited(pickAndSendBooking(context, room)),
    ),
  ];
}

/// The sender's language goes into the data: the message is the same for
/// everyone in the room, whatever their app language.
Future<void> sendSampleQuote(BuildContext context, ChatRoomController room) {
  final t = context.t.custom;
  return room.sendCustom(offerType, {
    'variant': quoteVariant,
    'title': t.customOrder,
    'currency': 'USD',
    'validDays': 3,
    'items': [
      {'label': t.wallet, 'amount': 40},
      {'label': t.engraving, 'amount': 8},
      {'label': t.giftBox, 'amount': 4},
    ],
  });
}

Future<void> pickAndSendBooking(
  BuildContext context,
  ChatRoomController room,
) async {
  final now = DateTime.now();
  final day = await showDatePicker(
    context: context,
    firstDate: now,
    lastDate: now.add(const Duration(days: 90)),
    initialDate: now.add(const Duration(days: 1)),
  );
  if (day == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 10, minute: 0),
  );
  if (time == null || !context.mounted) return;
  final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  await room.sendCustom(bookingType, {
    'title': context.t.custom.meeting,
    'at': at.toIso8601String(),
    'place': 'Café du Port, Oran',
  });
}

/// Asks for a title and a price, then sends a product offer.
Future<void> showOfferDialog(
  BuildContext context,
  ChatRoomController room,
) async {
  final offer = await showDialog<(String, num)>(
    context: context,
    builder: (_) => const _OfferDialog(),
  );
  if (offer == null) return;
  final (title, amount) = offer;
  await room.sendCustom(offerType, {
    'variant': productVariant,
    'title': title,
    'amount': amount,
    'currency': 'USD',
  });
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog();

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final amount = num.tryParse(_amount.text.trim());
    if (title.isEmpty || amount == null) return;
    Navigator.pop(context, (title, amount));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      title: Text(t.app.makeOffer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(labelText: t.custom.what),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t.custom.price,
              suffixText: 'USD',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.custom.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.custom.send)),
      ],
    );
  }
}
