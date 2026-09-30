import 'package:flutter/material.dart';

void main() => runApp(const ChatKitExampleApp());

class ChatKitExampleApp extends StatelessWidget {
  const ChatKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_chat_kit example',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const Scaffold(
        body: Center(
          child: Text('flutter_chat_kit: demo arrives with task T13'),
        ),
      ),
    );
  }
}
