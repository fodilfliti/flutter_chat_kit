import 'package:flutter/material.dart';
import 'package:flutter_chat_pro_example/i18n/strings.g.dart';

/// Switches the app language at runtime: the chat, the example screens and
/// the dates follow at once (Arabic also turns the layout right to left).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLocale>(
      tooltip: context.t.app.language,
      padding: const EdgeInsets.all(6),
      icon: const Icon(Icons.translate),
      initialValue: TranslationProvider.of(context).locale,
      onSelected: LocaleSettings.setLocaleSync,
      itemBuilder: (_) => [
        for (final locale in AppLocale.values)
          PopupMenuItem(
            value: locale,
            child: Text(locale.translations.languageName),
          ),
      ],
    );
  }
}
