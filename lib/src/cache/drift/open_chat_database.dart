import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens `chat_kit_<userId>.sqlite` in the app documents directory, on a
/// background isolate. On the web the app must serve `sqlite3.wasm` and
/// `drift_worker.js` from `web/`; `dart run flutter_chat_pro:web_setup`
/// downloads them.
QueryExecutor openChatDatabase(String userId) {
  return driftDatabase(
    name: chatDatabaseName(userId),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _unsafeChar = RegExp('[^A-Za-z0-9_-]');

/// File-safe database name for [userId]. Ids with other characters are
/// sanitized and suffixed with a hash so two ids never share a file.
String chatDatabaseName(String userId) {
  if (_safeId.hasMatch(userId)) return 'chat_kit_$userId';
  var readable = userId.replaceAll(_unsafeChar, '_');
  if (readable.length > 40) readable = readable.substring(0, 40);
  return 'chat_kit_${readable}_${_hash(userId)}';
}

// djb2 kept below 2^53 so it is identical on native and web.
String _hash(String value) {
  var hash = 5381;
  for (final byte in utf8.encode(value)) {
    hash = (hash * 33 + byte) % 4294967296;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
