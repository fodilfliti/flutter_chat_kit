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
  late final Future<void> _opened = _backend.kit.open();

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
      builder: (context, child) =>
          ChatKitScope(kit: _backend.kit, child: child!),
      home: FutureBuilder<void>(
        future: _opened,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Could not open: ${snapshot.error}')),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return InboxPage(backend: _backend);
        },
      ),
    );
  }
}
