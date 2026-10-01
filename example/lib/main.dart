import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';
import 'package:flutter_chat_kit_example/pages/inbox_page.dart';
import 'package:flutter_chat_kit_example/style/style_settings.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_scale_kit/flutter_scale_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  runApp(ChatKitExampleApp(devicePreview: _bigScreen));
}

/// A browser or a desktop window shows the app inside a phone frame.
bool get _bigScreen =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

class ChatKitExampleApp extends StatefulWidget {
  const ChatKitExampleApp({
    this.backend,
    this.style,
    this.devicePreview = false,
    super.key,
  });

  /// Tests pass one with an in-memory cache.
  final ExampleBackend? backend;
  final StyleSettings? style;

  /// Wraps the app in device_preview: a phone frame with a device picker,
  /// orientation, dark mode and text size tools.
  final bool devicePreview;

  @override
  State<ChatKitExampleApp> createState() => _ChatKitExampleAppState();
}

class _ChatKitExampleAppState extends State<ChatKitExampleApp> {
  late final ExampleBackend _backend = widget.backend ?? ExampleBackend();
  late final Future<void> _opened = _backend.open();
  late final StyleSettings _style = widget.style ?? StyleSettings();

  @override
  void dispose() {
    if (widget.backend == null) unawaited(_backend.close());
    if (widget.style == null) _style.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // slang rebuilds everything that reads `context.t` when the language
    // changes; MaterialApp's locale gives the chat localized dates and the
    // text direction.
    return TranslationProvider(
      child: DevicePreview(
        enabled: widget.devicePreview,
        defaultDevice: Devices.ios.iPhone13,
        // The app's own screen-size package sits inside the preview so it
        // measures the simulated phone; the chat uses its factors only when
        // "Scale kit" is picked in the style sheet.
        builder: (context) => ScaleKitBuilder(
          designWidth: 375,
          designHeight: 812,
          child: ListenableBuilder(
            listenable: _style,
            builder: (context, _) => MaterialApp(
              onGenerateTitle: (context) => context.t.app.title,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: _style.theme(Brightness.light),
              darkTheme: _style.theme(Brightness.dark),
              themeMode: _style.themeMode,
              // Switching profile rebuilds everything below with the new kit.
              builder: (context, child) => DevicePreview.appBuilder(
                context,
                StyleScope(
                  settings: _style,
                  child: ChatProfileScope(
                    switcher: _backend.switcher,
                    placeholder: _Opening(opened: _opened),
                    child: child!,
                  ),
                ),
              ),
              home: InboxPage(backend: _backend),
            ),
          ),
        ),
      ),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening({required this.opened});

  final Future<void> opened;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: opened,
      builder: (context, snapshot) => Scaffold(
        body: Center(
          child: snapshot.hasError
              ? Text(context.t.app.couldNotOpen(error: '${snapshot.error}'))
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
