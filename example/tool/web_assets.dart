// Downloads the two files drift needs on the web into `web/`, matching the
// versions in pubspec.lock:
//
//   dart run tool/web_assets.dart
//
// Run it from the example folder before `flutter run -d chrome` or
// `flutter build web`. Both files are git-ignored.
import 'dart:io';

Future<void> main() async {
  final lock = File('pubspec.lock').readAsStringSync();
  final sqlite3 = _version(lock, 'sqlite3');
  final drift = _version(lock, 'drift');
  const releases = 'https://github.com/simolus3';

  await _download(
    '$releases/sqlite3.dart/releases/download/sqlite3-$sqlite3/sqlite3.wasm',
    'web/sqlite3.wasm',
  );
  await _download(
    '$releases/drift/releases/download/drift-$drift/drift_worker.js',
    'web/drift_worker.js',
  );
}

String _version(String lock, String package) {
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock);
  if (match == null) {
    throw StateError('$package is not in pubspec.lock; run flutter pub get.');
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
