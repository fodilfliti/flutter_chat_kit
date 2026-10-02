import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = {
  'id': 'm1',
  'room_id': 'r1',
  'author_id': 'u1',
  'created_at': '2026-09-30T12:00:00Z',
};

void main() {
  group('Attachments', () {
    test('a bare URL string is the remote url, mime guessed', () {
      final a = Attachment.fromJson('https://cdn.test/a/photo.JPG?w=200#x');
      expect(a.remoteUrl, 'https://cdn.test/a/photo.JPG?w=200#x');
      expect(a.mimeType, 'image/jpeg');
      expect(a.kind, AttachmentKind.image);
    });

    test('"url" is read when "remote_url" is missing', () {
      final a = Attachment.fromJson(const {'url': 'https://cdn.test/v.mp4'});
      expect(a.remoteUrl, 'https://cdn.test/v.mp4');
      expect(a.kind, AttachmentKind.video);
    });

    test('an explicit mime type wins over the extension', () {
      final a = Attachment.fromJson(const {
        'remote_url': 'https://cdn.test/a.jpg',
        'mime_type': 'image/webp',
      });
      expect(a.mimeType, 'image/webp');
    });

    test('no extension uses the hint, then octet-stream', () {
      expect(
        Attachment.fromJson(
          'https://cdn.test/media/42',
          mimeHint: 'image/*',
        ).kind,
        AttachmentKind.image,
      );
      expect(
        Attachment.fromJson('https://cdn.test/media/42').mimeType,
        Attachment.fallbackMimeType,
      );
    });

    test('guessMimeType', () {
      expect(Attachment.guessMimeType('voice.m4a'), 'audio/mp4');
      expect(Attachment.guessMimeType('/docs/contract.PDF'), 'application/pdf');
      expect(Attachment.guessMimeType('https://x.test/a.b/file'), isNull);
      expect(Attachment.guessMimeType('https://x.test/'), isNull);
      expect(Attachment.guessMimeType(null), isNull);
    });

    test('image message with a list of URL strings', () {
      final m = Message.fromJson(const {
        ..._base,
        'type': 'image',
        'attachments': ['https://cdn.test/1.png', 'https://cdn.test/2'],
      });
      final images = (m as ImageMessage).images;
      expect(images.map((a) => a.remoteUrl), [
        'https://cdn.test/1.png',
        'https://cdn.test/2',
      ]);
      expect(images.every((a) => a.kind == AttachmentKind.image), isTrue);
    });

    test('image message with a single "attachment"', () {
      final m = Message.fromJson(const {
        ..._base,
        'type': 'image',
        'attachment': 'https://cdn.test/1.png',
      });
      expect((m as ImageMessage).images.single.remoteUrl, endsWith('1.png'));
    });

    test('video, audio and file accept URL strings and lists', () {
      final video = Message.fromJson(const {
        ..._base,
        'type': 'video',
        'attachment': 'https://cdn.test/clip',
      });
      expect((video as VideoMessage).video.kind, AttachmentKind.video);

      final audio = Message.fromJson(const {
        ..._base,
        'type': 'audio',
        'attachments': ['https://cdn.test/voice'],
        'duration_ms': 3000,
      });
      expect((audio as AudioMessage).audio.kind, AttachmentKind.audio);
      expect(audio.audio.remoteUrl, 'https://cdn.test/voice');

      final file = Message.fromJson(const {
        ..._base,
        'type': 'file',
        'attachment': {'url': 'https://cdn.test/report.pdf'},
      });
      expect((file as FileMessage).file.mimeType, 'application/pdf');
    });
  });

  group('Message fields', () {
    test('roomId fills a missing room id', () {
      final json = Map<String, Object?>.of(_base)..remove('room_id');
      final m = Message.fromJson({...json, 'text': 'hi'}, roomId: 'r9');
      expect(m.roomId, 'r9');
    });

    test('the room id in the JSON wins over roomId', () {
      final m = Message.fromJson(_base, roomId: 'other');
      expect(m.roomId, 'r1');
    });

    test('a missing room id names the field and the fix', () {
      final json = Map<String, Object?>.of(_base)..remove('room_id');
      expect(
        () => Message.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"m1"'), contains('room_id'), contains('roomId:')),
          ),
        ),
      );
    });

    test('a missing author names the key to set', () {
      final json = Map<String, Object?>.of(_base)..remove('author_id');
      expect(
        () => Message.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('ChatJsonKeys(authorId:'),
          ),
        ),
      );
    });

    test('a bad date names the message and the field', () {
      expect(
        () => Message.fromJson({..._base}..['created_at'] = 'yesterday'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"m1"'), contains('created_at')),
          ),
        ),
      );
    });

    test('epoch seconds, milliseconds and numeric strings', () {
      final expected = DateTime.utc(2026, 9, 30, 12);
      final seconds = expected.millisecondsSinceEpoch ~/ 1000;
      for (final value in [
        seconds,
        expected.millisecondsSinceEpoch,
        '$seconds',
        seconds + 0.0,
      ]) {
        final m = Message.fromJson({..._base, 'created_at': value});
        expect(m.createdAt, expected, reason: '$value');
      }
    });

    test('status aliases and case', () {
      MessageStatus status(String value) =>
          Message.fromJson({..._base, 'status': value}).status;
      expect(status('read'), MessageStatus.seen);
      expect(status('SEEN'), MessageStatus.seen);
      expect(status('received'), MessageStatus.delivered);
      expect(status('Delivered'), MessageStatus.delivered);
      expect(status('whatever'), MessageStatus.sent);
      expect(MessageStatus.isKnown('Read'), isTrue);
      expect(MessageStatus.isKnown('opened'), isFalse);
    });
  });

  group('Rooms', () {
    test('updated_at falls back to the last message time', () {
      final room = ChatRoom.fromJson(const {
        'id': 'r1',
        'last_message': {
          'id': 'm1',
          'author_id': 'u1',
          'created_at': '2026-09-30T12:00:00Z',
          'text': 'hi',
        },
      });
      expect(room.updatedAt, DateTime.utc(2026, 9, 30, 12));
      expect(room.lastMessage!.roomId, 'r1');
    });

    test('no updated_at and no last message explains the fix', () {
      expect(
        () => ChatRoom.fromJson(const {'id': 'r1'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('RoomJsonKeys(updatedAt:'),
          ),
        ),
      );
    });

    test('members can be plain user ids', () {
      final room = ChatRoom.fromJson(const {
        'id': 'r1',
        'updated_at': 1790000000,
        'members': ['u1', 'u2', 7],
      });
      expect(room.members.map((m) => m.userId), ['u1', 'u2', '7']);
      expect(room.members.first.role, MemberRole.member);
    });
  });
}
