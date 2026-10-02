import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

TextMessage _m(int i) {
  final id = 'm${i.toString().padLeft(4, '0')}';
  return TextMessage(
    id: id,
    localId: id,
    roomId: 'r1',
    authorId: 'u2',
    createdAt: _t0.add(Duration(seconds: i)),
    text: id,
  );
}

/// A page-number API over [messages], newest first.
class _PageApi {
  _PageApi(Iterable<int> ids) : messages = [for (final i in ids) _m(i)];

  final List<Message> messages;
  final List<int> pages = [];

  Future<List<Object?>> fetchPage(
    String roomId, {
    required int page,
    required int size,
    int first = 1,
  }) async {
    pages.add(page);
    final sorted = [...messages]..sort((a, b) => b.cursor.compareTo(a.cursor));
    final start = (page - first) * size;
    if (start >= sorted.length) return const [];
    final end = (start + size).clamp(0, sorted.length);
    return [for (final m in sorted.sublist(start, end)) m.toJson()];
  }
}

void main() {
  late _PageApi api;

  PagedMessages build({int pageSize = 10, int maxPages = 20}) {
    return PagedMessages(
      fetchPage: api.fetchPage,
      decode: (json, roomId) => Message.fromJson(json, roomId: roomId),
      pageSize: pageSize,
      maxPages: maxPages,
    );
  }

  List<String> ids(ChatPage<Message> page) => [
    for (final m in page.items) m.id,
  ];
  List<String> range(int from, int to) => [
    for (var i = from; i >= to; i--) _m(i).id,
  ];

  test('no cursor returns the latest messages', () async {
    api = _PageApi(List.generate(50, (i) => i));
    final page = await build().fetch('r1', limit: 15);

    expect(ids(page), range(49, 35));
    expect(page.hasMore, isTrue);
    expect(api.pages, [1, 2]);
  });

  test('scrolling back resumes from the last page, no gaps', () async {
    api = _PageApi(List.generate(95, (i) => i));
    final paged = build();
    final seen = <String>[];
    var page = await paged.fetch('r1', limit: 10);
    seen.addAll(ids(page));
    while (page.hasMore) {
      page = await paged.fetch('r1', before: page.items.last.cursor, limit: 10);
      seen.addAll(ids(page));
    }

    expect(seen, range(94, 0));
    // Walking from page 1 every time would take 55 requests.
    expect(api.pages.length, lessThanOrEqualTo(20));
  });

  test('new messages shifting pages cause no duplicates or gaps', () async {
    api = _PageApi(List.generate(40, (i) => i));
    final paged = build();
    final first = await paged.fetch('r1', limit: 10);

    api.messages.addAll([for (var i = 40; i < 47; i++) _m(i)]);
    final next = await paged.fetch(
      'r1',
      before: first.items.last.cursor,
      limit: 10,
    );

    expect(ids(first), range(39, 30));
    expect(ids(next), range(29, 20));
  });

  test('deletions shifting pages back cause no gaps', () async {
    api = _PageApi(List.generate(40, (i) => i));
    final paged = build();
    final first = await paged.fetch('r1', limit: 10);
    final second = await paged.fetch(
      'r1',
      before: first.items.last.cursor,
      limit: 10,
    );
    expect(ids(second), range(29, 20));

    api.messages.removeWhere((m) => m.id.compareTo(_m(30).id) >= 0);
    final third = await paged.fetch(
      'r1',
      before: second.items.last.cursor,
      limit: 10,
    );

    expect(ids(third), range(19, 10));
  });

  test('after returns the oldest newer messages, newest first', () async {
    api = _PageApi(List.generate(60, (i) => i));
    final paged = build();

    final page = await paged.fetch('r1', after: _m(30).cursor, limit: 10);
    expect(ids(page), range(40, 31));
    expect(page.hasMore, isTrue);

    final last = await paged.fetch('r1', after: _m(52).cursor, limit: 10);
    expect(ids(last), range(59, 53));
    expect(last.hasMore, isFalse);
    expect(api.pages, [1, 2, 3, 1]);
  });

  test('the end of history reports no more', () async {
    api = _PageApi(List.generate(25, (i) => i));
    final paged = build();
    final short = await paged.fetch('r1');
    expect(short.items, hasLength(25));
    expect(short.hasMore, isFalse);

    // A full last page can't tell; the next call answers.
    final page = await paged.fetch('r1', limit: 20);
    expect(page.hasMore, isTrue);
    final end = await paged.fetch(
      'r1',
      before: page.items.last.cursor,
      limit: 20,
    );
    expect(ids(end), range(4, 0));
    expect(end.hasMore, isFalse);
  });

  test('maxPages bounds the requests and keeps hasMore', () async {
    api = _PageApi(List.generate(200, (i) => i));
    final page = await build(
      maxPages: 3,
    ).fetch('r1', after: _m(10).cursor, limit: 10);

    expect(api.pages, [1, 2, 3]);
    expect(page.hasMore, isTrue);
  });

  test('userOf returns the senders of the returned messages', () async {
    api = _PageApi(List.generate(5, (i) => i));
    final paged = PagedMessages(
      fetchPage: api.fetchPage,
      decode: (json, roomId) => Message.fromJson(json, roomId: roomId),
      userOf: (json) => ChatUser(id: '${json['author_id']}', name: 'Sara'),
    );
    final page = await paged.fetch('r1');

    expect(page.users, [const ChatUser(id: 'u2', name: 'Sara')]);
  });

  test('zero-based pages', () async {
    api = _PageApi(List.generate(25, (i) => i));
    final paged = PagedMessages(
      fetchPage: (roomId, {required page, required size}) =>
          api.fetchPage(roomId, page: page, size: size, first: 0),
      decode: (json, roomId) => Message.fromJson(json, roomId: roomId),
      pageSize: 10,
      firstPage: 0,
    );
    final page = await paged.fetch('r1', limit: 25);

    expect(ids(page), range(24, 0));
    expect(page.hasMore, isFalse);
    expect(api.pages, [0, 1, 2]);
  });
}
