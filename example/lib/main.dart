import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/backend.dart';
import 'package:flutter_chat_kit_example/pages/inbox_page.dart';

void main() => runApp(const ChatKitExampleApp());

class ChatKitExampleApp extends StatefulWidget {
  const ChatKitExampleApp({this.backend, super.key});

  /// Tests pass one with an in-memory cache.
  final ExampleBackend? backend;

  @override
  State<ChatKitExampleApp> createState() => _ChatKitExampleAppState();
}

class _ChatKitExampleAppState extends State<ChatKitExampleApp> {
  late final ExampleBackend _backend = widget.backend ?? ExampleBackend();
  late final Future<void> _opened = _backend.open();

  @override
  void dispose() {
    if (widget.backend == null) unawaited(_backend.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Colors.teal;
    return MaterialApp(
      title: 'flutter_chat_kit example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      // Switching profile rebuilds everything below with the new kit.
      builder: (context, child) => ChatProfileScope(
        switcher: _backend.switcher,
        placeholder: _Opening(opened: _opened),
        child: child!,
      ),
      home: InboxPage(backend: _backend),
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
