import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';

/// The `customType` of offer messages.
const offerType = 'offer';

/// Inbox and reply preview text for custom messages.
String? customPreview(String customType, Map<String, Object?> data) {
  if (customType != offerType) return null;
  return 'Offer: ${data['title']} (${_price(data)})';
}

String _price(Map<String, Object?> data) {
  final amount = data['amount'];
  final currency = data['currency'] ?? 'USD';
  return '$amount $currency';
}

/// Renders a `CustomMessage('offer')`: registered in
/// `ChatBuilders.customBuilders`.
CustomMessageBuilder offerBuilder(ChatRoomController room) {
  return (context, message) => OfferCard(
    message: message,
    onRespond: (accepted) => unawaited(
      room.sendText(
        accepted ? 'Deal! ✅' : 'No thanks, maybe next time',
        replyToId: message.message.id,
      ),
    ),
  );
}

class OfferCard extends StatelessWidget {
  const OfferCard({required this.message, this.onRespond, super.key});

  final MessageContext message;
  final ValueChanged<bool>? onRespond;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final m = message.message as CustomMessage;
    final title = '${m.data['title'] ?? ''}';
    final onRespond = this.onRespond;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Card(
        margin: EdgeInsets.zero,
        color: message.isMine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Offer',
                    style: text.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                _price(m.data),
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!message.isMine && onRespond != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond(false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRespond(true),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a title and a price, then sends an offer.
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
    return AlertDialog(
      title: const Text('Make an offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'What'),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price',
              suffixText: 'USD',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }
}

/// The "Offer" entry of the attachment sheet.
AttachmentOption offerOption(BuildContext context, ChatRoomController room) {
  return AttachmentOption(
    icon: Icons.local_offer_outlined,
    label: 'Offer',
    onSelected: () => unawaited(showOfferDialog(context, room)),
  );
}
