import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/pages/inbox_page.dart';
import 'package:flutter_chat_kit_example/style/style_settings.dart';

void main() => runApp(const ChatKitExampleApp());

class ChatKitExampleApp extends StatefulWidget {
  const ChatKitExampleApp({this.backend, this.style, super.key});

  /// Tests pass one with an in-memory cache.
  final ExampleBackend? backend;
  final StyleSettings? style;

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
    // A new ThemeData per change: every chat widget reads ChatTheme in
    // build, so the whole app restyles (and rescales) at once.
    return ListenableBuilder(
      listenable: _style,
      builder: (context, _) => MaterialApp(
        title: 'flutter_chat_kit example',
        debugShowCheckedModeBanner: false,
        theme: _style.theme(Brightness.light),
        darkTheme: _style.theme(Brightness.dark),
        themeMode: _style.themeMode,
        // Switching profile rebuilds everything below with the new kit.
        builder: (context, child) => StyleScope(
          settings: _style,
          child: ChatProfileScope(
            switcher: _backend.switcher,
            placeholder: _Opening(opened: _opened),
            child: child!,
          ),
        ),
        home: InboxPage(backend: _backend),
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
              ? Text('Could not open: ${snapshot.error}')
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
