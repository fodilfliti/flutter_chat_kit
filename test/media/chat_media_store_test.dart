import 'dart:io';

import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

import '../cache/memory_cache.dart';
import '../source/fake_chat_source.dart';

void main() {
  late Directory root;
  late DriftChatCache cache;
  late List<Uri> requests;
  late MockClient client;
  var now = DateTime.utc(2026, 9, 30);
  var status = 200;

  ChatMediaStore store({int? maxBytes, SaveMediaCallback? onSave}) =>
      ChatMediaStore(
        userId: 'me',
        cache: cache,
        client: client,
        rootDirectory: () async => root,
        clock: () => now,
        maxBytes: maxBytes,
        onSave: onSave,
      );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('chat_media_');
    cache = memoryCache(clock: () => now);
    await cache.open('me');
    requests = [];
    status = 200;
    client = MockClient((request) async {
      requests.add(request.url);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response(
        'x' * 10,
        status,
        headers: {'content-type': 'image/jpeg'},
      );
    });
  });

  tearDown(() async {
    await cache.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('downloads once; later views read the stored file', () async {
    const url = 'https://cdn.test/a/photo';
    final first = store();
    final file = await first.fetch(url);
    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('.jpg'));
    expect(first.peek(url)?.path, file.path);

    // A new store (for example after a restart) finds it through the index.
    final second = store();
    expect(second.peek(url), isNull);
    expect((await second.fetch(url)).path, file.path);
    expect(requests, hasLength(1));
  });

  test('concurrent fetches share one download', () async {
    const url = 'https://cdn.test/b.jpg';
    final s = store();
    final files = await Future.wait([s.fetch(url), s.fetch(url)]);
    expect(files[0].path, files[1].path);
    expect(requests, hasLength(1));
    expect(s.downloadProgress(url).value, isNull);
  });

  test('adopted uploads never download', () async {
    final local = File('${root.path}/local.m4a')..writeAsStringSync('voice');
    const url = 'https://cdn.test/v/voice';
    final s = store();
    await s.adopt(local.path, url, mimeType: 'audio/mp4');
    final file = await s.fetch(url);
    expect(file.readAsStringSync(), 'voice');
    expect(file.path, endsWith('.m4a'));
    expect(requests, isEmpty);
  });

  test('evicts the least recently used files past maxBytes', () async {
    final s = store(maxBytes: 25);
    now = DateTime.utc(2026, 9, 30, 1);
    final a = await s.fetch('https://cdn.test/a.jpg');
    now = DateTime.utc(2026, 9, 30, 2);
    final b = await s.fetch('https://cdn.test/b.jpg');
    now = DateTime.utc(2026, 9, 30, 3);
    await s.fetch('https://cdn.test/a.jpg');
    now = DateTime.utc(2026, 9, 30, 4);
    final c = await s.fetch('https://cdn.test/c.jpg');

    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isFalse);
    expect(c.existsSync(), isTrue);
    expect(await s.file('https://cdn.test/b.jpg'), isNull);
    expect(requests, hasLength(3));
  });

  test('HTTP errors throw ServerFailure and leave no file', () async {
    status = 404;
    final s = store();
    await expectLater(
      s.fetch('https://cdn.test/missing.jpg'),
      throwsA(isA<ServerFailure>()),
    );
    expect(await s.file('https://cdn.test/missing.jpg'), isNull);
    final leftovers = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.part'));
    expect(leftovers, isEmpty);
  });

  test('save goes through onSave with the URL file name', () async {
    File? saved;
    String? savedName;
    String? savedType;
    final s = store(
      onSave: (file, {name, mimeType}) async {
        saved = file;
        savedName = name;
        savedType = mimeType;
        return true;
      },
    );
    final ok = await s.save('https://cdn.test/docs/My%20Photo.jpg');
    expect(ok, isTrue);
    expect(saved?.existsSync(), isTrue);
    expect(savedName, 'My Photo.jpg');
    expect(savedType, 'image/jpeg');
  });

  test('clear deletes the files and the index', () async {
    final s = store();
    final file = await s.fetch('https://cdn.test/a.jpg');
    await s.clear();
    expect(file.existsSync(), isFalse);
    expect(await cache.mediaEntries(), isEmpty);
    expect(s.peek('https://cdn.test/a.jpg'), isNull);
  });

  test('clearUserData removes the kit media', () async {
    await cache.close();
    final source = FakeChatSource();
    final kit = ChatKit(
      currentUserId: 'me',
      source: source,
      cache: cache,
      mediaStore: (kit) => ChatMediaStore(
        userId: kit.currentUserId,
        cache: kit.cache,
        client: client,
        rootDirectory: () async => root,
      ),
    );
    await kit.open();
    final file = await kit.media.fetch('https://cdn.test/a.jpg');
    expect(file.existsSync(), isTrue);
    await kit.clearUserData();
    expect(file.existsSync(), isFalse);
    await kit.close();
    await source.dispose();
  });
}
