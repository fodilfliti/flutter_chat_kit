import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 9, 30, 12);

const _image = Attachment(
  mimeType: 'image/jpeg',
  remoteUrl: 'https://cdn.test/a.jpg',
  width: 1200,
  height: 800,
  size: 204800,
);

List<Message> _allTypes() => [
  TextMessage(
    id: 'm1',
    localId: 'l1',
    roomId: 'r1',
    authorId: 'u1',
    createdAt: _t0,
    text: 'hello',
    replyToId: 'm0',
    reactions: const {
      '👍': {'u2', 'u3'},
    },
    metadata: const {
      'priority': 2,
      'tags': ['a', 'b'],
    },
    editedAt: _t0.add(const Duration(minutes: 1)),
  ),
  ImageMessage(
    id: 'm2',
    localId: 'l2',
    roomId: 'r1',
    authorId: 'u1',
    createdAt: _t0,
    images: const [_image, _image],
    caption: 'trip',
  ),
  VideoMessage(
    id: 'm3',
    localId: 'l3',
    roomId: 'r1',
    authorId: 'u1',
    createdAt: _t0,
    video: const Attachment(
      mimeType: 'video/mp4',
      remoteUrl: 'https://cdn.test/v.mp4',
      thumbnailUrl: 'https://cdn.test/v.jpg',
      duration: Duration(seconds: 12),
    ),
  ),
  AudioMessage(
    id: 'm4',
    localId: 'l4',
    roomId: 'r1',
    authorId: 'u1',
    createdAt: _t0,
    audio: const Attachment(mimeType: 'audio/m4a', localPath: '/tmp/v.m4a'),
    duration: const Duration(seconds: 7),
    waveform: const [0.1, 0.5, 1],
    status: MessageStatus.pending,
  ),
  FileMessage(
    id: 'm5',
    localId: 'l5',
    roomId: 'r1',
    authorId: 'u1',
    createdAt: _t0,
    file: const Attachment(
      mimeType: 'application/pdf',
      name: 'contract.pdf',
      size: 1048576,
    ),
    status: MessageStatus.failed,
  ),
  SystemMessage(
    id: 'm6',
    localId: 'm6',
    roomId: 'r1',
    authorId: 'system',
    createdAt: _t0,
    code: 'member_joined',
    args: const {'user': 'Ana'},
  ),
  CustomMessage(
    id: 'm7',
    localId: 'l7',
    roomId: 'r1',
    authorId: 'u2',
    createdAt: _t0,
    customType: 'offer',
    data: const {'title': 'Bag', 'price': 20.5},
    deletedAt: _t0.add(const Duration(hours: 1)),
  ),
];

void main() {
  group('Message JSON', () {
    for (final message in _allTypes()) {
      test('round-trips ${message.type}', () {
        final json = message.toJson();
        expect(Message.fromJson(json), message);
      });
    }

    test('preserves metadata untouched', () {
      final text = _allTypes().first;
      final decoded = Message.fromJson(text.toJson());
      expect(decoded.metadata, {
        'priority': 2,
        'tags': ['a', 'b'],
      });
    });

    test('unknown type decodes to CustomMessage with remaining fields', () {
      final message = Message.fromJson(const {
        'type': 'offer',
        'id': 'x',
        'room_id': 'r1',
        'author_id': 'u1',
        'created_at': '2026-09-30T12:00:00Z',
        'title': 'Bag',
        'price': 20,
      });
      expect(message, isA<CustomMessage>());
      final custom = message as CustomMessage;
      expect(custom.customType, 'offer');
      expect(custom.data, {'title': 'Bag', 'price': 20});
    });

    test('missing local_id falls back to id; missing status is sent', () {
      final message = Message.fromJson(const {
        'id': 'server-1',
        'room_id': 'r1',
        'author_id': 'u1',
        'created_at': 1790000000000,
        'text': 'hi',
      });
      expect(message.localId, 'server-1');
      expect(message.status, MessageStatus.sent);
      expect(message, isA<TextMessage>());
      expect(message.createdAt.isUtc, isTrue);
    });

    test('custom keys and type aliases', () {
      const keys = ChatJsonKeys(
        authorId: 'senderId',
        roomId: 'conversationId',
        createdAt: 'timestamp',
        text: 'message',
        type: 'messageType',
        typeAliases: {'msg': 'text'},
      );
      final message = Message.fromJson(const {
        'messageType': 'msg',
        'id': 'a',
        'conversationId': 'c1',
        'senderId': 'u9',
        'timestamp': 1790000000000,
        'message': 'salam',
      }, keys: keys);

      expect(message, isA<TextMessage>());
      expect((message as TextMessage).text, 'salam');
      expect(message.authorId, 'u9');
      expect(message.toJson(keys: keys)['senderId'], 'u9');
    });

    test('throws FormatException without id and local_id', () {
      expect(
        () => Message.fromJson(const {
          'room_id': 'r1',
          'author_id': 'u1',
          'created_at': '2026-09-30T12:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('Message helpers', () {
    test('copyWith keeps subtype and changes base fields', () {
      final text = _allTypes().first as TextMessage;
      final sent = text.copyWith(id: 'server', status: MessageStatus.seen);
      expect(sent, isA<TextMessage>());
      expect(sent.text, 'hello');
      expect(sent.localId, 'l1');
      expect(sent.id, 'server');
    });

    test('copyWith through the base type keeps the subtype', () {
      final message = _allTypes()[1];
      expect(message.copyWith(status: MessageStatus.sent), isA<ImageMessage>());
    });

    test('matches id or localId', () {
      final text = _allTypes().first;
      expect(text.matches('m1'), isTrue);
      expect(text.matches('l1'), isTrue);
      expect(text.matches('zz'), isFalse);
    });

    test('value equality', () {
      expect(_allTypes().first, _allTypes().first);
      expect(_allTypes().first.hashCode, _allTypes().first.hashCode);
    });
  });

  group('Attachment', () {
    test('kind and aspect ratio', () {
      expect(_image.kind, AttachmentKind.image);
      expect(_image.aspectRatio, 1.5);
      expect(
        const Attachment(mimeType: 'application/zip').kind,
        AttachmentKind.file,
      );
      expect(const Attachment(mimeType: 'image/png').aspectRatio, isNull);
    });

    test('source prefers remote url', () {
      const a = Attachment(mimeType: 'image/png', localPath: '/a.png');
      expect(a.source, '/a.png');
      expect(a.isUploaded, isFalse);
      expect(
        a.copyWith(remoteUrl: 'https://x/a.png').source,
        'https://x/a.png',
      );
    });
  });
}
