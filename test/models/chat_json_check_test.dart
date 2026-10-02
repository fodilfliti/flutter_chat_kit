import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = {
  'id': 'm1',
  'room_id': 'r1',
  'author_id': 'u1',
  'created_at': '2026-09-30T12:00:00Z',
};

Matcher _issue(String field, String text, {bool isError = false}) =>
    isA<ChatJsonIssue>()
        .having((i) => i.field, 'field', field)
        .having((i) => i.message, 'message', contains(text))
        .having((i) => i.isError, 'isError', isError);

void main() {
  group('message', () {
    test('a complete message has no issues', () {
      expect(ChatJsonCheck.message({..._base, 'text': 'hi'}), isEmpty);
      expect(
        ChatJsonCheck.message({
          ..._base,
          'type': 'image',
          'attachments': [
            {
              'remote_url': 'https://cdn.test/a.jpg',
              'mime_type': 'image/jpeg',
              'width': 4,
              'height': 3,
            },
          ],
        }),
        isEmpty,
      );
    });

    test('an unreadable message is one error with the fix', () {
      final json = Map<String, Object?>.of(_base)..remove('room_id');
      expect(ChatJsonCheck.message(json), [
        _issue('id', 'roomId:', isError: true),
      ]);
      expect(
        ChatJsonCheck.message({...json, 'text': 'x'}, roomId: 'r1'),
        isEmpty,
      );
    });

    test('dates: epoch seconds and missing time zone', () {
      final issues = ChatJsonCheck.message({
        ..._base,
        'text': 'hi',
        'created_at': 1790000000,
        'edited_at': '2026-09-30T12:00:00',
      });
      expect(issues, [
        _issue('created_at', 'epoch seconds'),
        _issue('edited_at', 'no time zone'),
      ]);
      expect(
        ChatJsonCheck.message({
          ..._base,
          'text': 'hi',
          'created_at': '2026-09-30T12:00:00.123+01:00',
        }),
        isEmpty,
      );
    });

    test('status: unknown and client-only values', () {
      expect(ChatJsonCheck.message({..._base, 'text': 'a', 'status': 'x'}), [
        _issue('status', 'read as sent'),
      ]);
      expect(
        ChatJsonCheck.message({..._base, 'text': 'a', 'status': 'pending'}),
        [_issue('status', 'only exists on the sending phone')],
      );
      expect(
        ChatJsonCheck.message({..._base, 'text': 'a', 'status': 'read'}),
        isEmpty,
      );
    });

    test('attachments: no URL, guessed mime, no size', () {
      expect(
        ChatJsonCheck.message({
          ..._base,
          'type': 'image',
          'attachments': [
            {'name': 'a'},
            'https://cdn.test/b.png',
            'https://cdn.test/c',
          ],
        }),
        [
          _issue('attachments[0]', 'no URL', isError: true),
          _issue('attachments[1]', 'guessed image/png'),
          _issue('attachments[1]', 'changes size'),
          _issue('attachments[2]', 'guessed image/*'),
          _issue('attachments[2]', 'changes size'),
        ],
      );
      expect(ChatJsonCheck.message({..._base, 'type': 'video'}), [
        _issue('attachment', 'no URL', isError: true),
      ]);
      expect(
        ChatJsonCheck.message({
          ..._base,
          'type': 'file',
          'attachment': 'https://cdn.test/blob',
        }),
        [_issue('attachment', 'shown as a file')],
      );
    });

    test('empty text, voice without duration, unknown type', () {
      expect(ChatJsonCheck.message(_base), [_issue('text', 'empty')]);
      expect(
        ChatJsonCheck.message({
          ..._base,
          'type': 'audio',
          'attachment': {
            'remote_url': 'https://cdn.test/v.m4a',
            'mime_type': 'audio/mp4',
          },
        }),
        [_issue('duration_ms', '0:00')],
      );
      expect(ChatJsonCheck.message({..._base, 'type': 'location'}), [
        _issue('type', 'customBuilders["location"]'),
      ]);
      expect(
        ChatJsonCheck.message({
          ..._base,
          'type': 'custom',
          'custom_type': 'offer',
        }),
        isEmpty,
      );
    });
  });

  group('room and user', () {
    test('room without members, timestamp from the last message', () {
      final issues = ChatJsonCheck.room(const {
        'id': 'r1',
        'last_message': {
          'id': 'm1',
          'author_id': 'u1',
          'created_at': 1790000000,
          'text': 'hi',
        },
      });
      expect(issues, [
        _issue('updated_at', 'last message time is used'),
        _issue('members', 'read receipts'),
        _issue('last_message.created_at', 'epoch seconds'),
      ]);
    });

    test('unreadable room', () {
      expect(
        ChatJsonCheck.room(const {'title': 'x'}),
        contains(_issue('id', 'Room needs "id"', isError: true)),
      );
    });

    test('user without name; camelCase keys', () {
      expect(ChatJsonCheck.user(const {'id': 'u1'}), [
        _issue('name', 'empty name'),
      ]);
      expect(
        ChatJsonCheck.user(const {
          'id': 'u1',
          'name': 'Ana',
          'avatarUrl': 'https://x',
        }, keys: ChatJsonKeys.camelCase),
        isEmpty,
      );
    });

    test('toString says error or warning', () {
      expect(
        const ChatJsonIssue('a', 'b', isError: true).toString(),
        'error a: b',
      );
      expect(const ChatJsonIssue('a', 'b').toString(), 'warning a: b');
    });
  });
}
