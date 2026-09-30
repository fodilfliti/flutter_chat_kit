import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';

/// An in-memory [DriftChatCache]; [opened] records the requested user ids.
DriftChatCache memoryCache({
  List<String>? opened,
  DateTime Function() clock = DateTime.now,
}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return DriftChatCache(
    clock: clock,
    executorFactory: (userId) {
      opened?.add(userId);
      return NativeDatabase.memory();
    },
  );
}
