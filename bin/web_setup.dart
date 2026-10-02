// Downloads the two files the chat cache needs on the web into `web/`,
// matching the drift and sqlite3 versions in your pubspec.lock:
//
//   dart run flutter_chat_kit:web_setup
//
// Run it from your app folder (the one with pubspec.yaml and web/) after
// `flutter pub get`, and again after upgrading drift or sqlite3. You can
// commit the two files or git-ignore them and run this in CI before
// `flutter build web`.
import 'dart:io';

const _releases = 'https://github.com/simolus3';

Future<void> main() async {
  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    _fail(
      'No pubspec.lock here. Run this from your app folder after '
      '`flutter pub get`.',
    );
  }
  if (!Directory('web').existsSync()) {
    _fail(
      'No web/ folder here. Add web support first: '
      '`flutter create --platforms web .`',
    );
  }

  final lock = lockFile.readAsStringSync();
  final sqlite3 = _version(lock, 'sqlite3');
  final drift = _version(lock, 'drift');

  try {
    await _download(
      '$_releases/sqlite3.dart/releases/download/sqlite3-$sqlite3/sqlite3.wasm',
      'web/sqlite3.wasm',
    );
    await _download(
      '$_releases/drift/releases/download/drift-$drift/drift_worker.js',
      'web/drift_worker.js',
    );
  } on IOException catch (e) {
    _fail('Download failed: $e');
  }
  stdout.writeln('Done. The chat cache now works on the web.');
}

String _version(String lock, String package) {
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock.replaceAll('\r\n', '\n'));
  if (match == null) {
    _fail('$package is not in pubspec.lock; run `flutter pub get` first.');
  }
  return match[1]!;
}

Future<void> _download(String url, String path) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('${response.statusCode} for $url');
    }
    await response.pipe(File(path).openWrite());
    stdout.writeln('$path <- $url');
  } finally {
    client.close();
  }
}

Never _fail(String message) {
  stderr.writeln('web_setup: $message');
  exit(1);
}
