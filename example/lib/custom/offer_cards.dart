import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/custom/custom_messages.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';

/// A standalone card that follows the chat theme: the bubble radius, the
/// scale (`theme.size`) and the text scale (`theme.fontSize`).
class _OfferFrame extends StatelessWidget {
  const _OfferFrame({
    required this.message,
    required this.icon,
    required this.label,
    required this.children,
  });

  final MessageContext message;
  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: theme.size(270)),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: message.isMine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            theme.bubble(isMine: message.isMine).radius,
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.size(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: theme.size(18), color: scheme.primary),
                  SizedBox(width: theme.size(6)),
                  Text(
                    label,
                    style: text.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontSize: theme.fontSize(14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.size(8)),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// `offer` with `variant: product`: one item and a price.
class ProductOfferCard extends StatelessWidget {
  const ProductOfferCard({required this.message, this.onRespond, super.key});

  final MessageContext message;
  final ValueChanged<bool>? onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final text = Theme.of(context).textTheme;
    final data = (message.message as CustomMessage).data;
    final onRespond = this.onRespond;
    final t = context.t.custom;
    return _OfferFrame(
      message: message,
      icon: Icons.local_offer,
      label: t.offer,
      children: [
        Text(
          '${data['title'] ?? ''}',
          style: text.titleMedium?.copyWith(fontSize: theme.fontSize(16)),
        ),
        SizedBox(height: theme.size(4)),
        Text(
          formatAmount(data['amount'], data),
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: theme.fontSize(24),
          ),
        ),
        if (!message.isMine && onRespond != null) ...[
          SizedBox(height: theme.size(12)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onRespond(false),
                  child: Text(t.decline),
                ),
              ),
              SizedBox(width: theme.size(8)),
              Expanded(
                child: FilledButton(
                  onPressed: () => onRespond(true),
                  child: Text(t.accept),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// `offer` with `variant: quote`: line items, a total and a validity.
class QuoteCard extends StatelessWidget {
  const QuoteCard({required this.message, this.onAccept, super.key});

  final MessageContext message;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final data = (message.message as CustomMessage).data;
    final items = [
      for (final item in data['items'] as List? ?? const [])
        if (item is Map) item,
    ];
    final line = text.bodyMedium?.copyWith(fontSize: theme.fontSize(14));
    final onAccept = this.onAccept;
    final t = context.t.custom;
    return _OfferFrame(
      message: message,
      icon: Icons.request_quote,
      label: t.quote,
      children: [
        Text(
          '${data['title'] ?? ''}',
          style: text.titleMedium?.copyWith(fontSize: theme.fontSize(16)),
        ),
        SizedBox(height: theme.size(8)),
        for (final item in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.size(2)),
            child: Row(
              children: [
                Expanded(child: Text('${item['label']}', style: line)),
                Text(formatAmount(item['amount'], data), style: line),
              ],
            ),
          ),
        Divider(height: theme.size(16)),
        Row(
          children: [
            Expanded(
              child: Text(
                t.total,
                style: line?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              formatAmount(quoteTotal(data), data),
              style: line?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (data['validDays'] case final int days) ...[
          SizedBox(height: theme.size(4)),
          Text(
            t.validFor(n: days),
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: theme.fontSize(12),
            ),
          ),
        ],
        if (!message.isMine && onAccept != null) ...[
          SizedBox(height: theme.size(10)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onAccept,
              child: Text(t.acceptQuote),
            ),
          ),
        ],
      ],
    );
  }
}
