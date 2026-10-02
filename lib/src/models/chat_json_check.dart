import 'package:flutter_chat_pro/src/models/attachment.dart';
import 'package:flutter_chat_pro/src/models/chat_json_keys.dart';
import 'package:flutter_chat_pro/src/models/chat_room.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/json_utils.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_status.dart';

/// One finding of [ChatJsonCheck]. `toString` prints
/// `error created_at: ...` or `warning attachments[0]: ...`.
class ChatJsonIssue {
  /// A finding about [field].
  const ChatJsonIssue(this.field, this.message, {this.isError = false});

  /// The JSON field, such as `created_at` or `attachments[0]`.
  final String field;

  /// What is wrong and how to fix it, in plain words.
  final String message;

  /// The JSON cannot be read; otherwise it is read with a guess or with
  /// something missing on screen.
  final bool isError;

  @override
  String toString() => '${isError ? 'error' : 'warning'} $field: $message';
}

/// Checks JSON from your backend against what the kit reads, and explains
/// each problem in plain words. It never throws.
///
/// Errors are JSON the kit cannot read, or that shows nothing. Warnings are
/// read with a guess (epoch seconds, a date without a time zone, a guessed
/// mime type, an unknown type) or with something missing on screen (no
/// image size, no audio length, no members). An empty list means the kit
/// reads everything it needs. See doc/backend_json.md.
///
/// Use it once on real responses while writing a `ChatSource`:
///
/// ```dart
/// test('my API messages', () {
///   final json = jsonDecode(File('test/fixtures/message.json')
///       .readAsStringSync()) as Map<String, Object?>;
///   expect(ChatJsonCheck.message(json, keys: myKeys), isEmpty);
/// });
/// ```
abstract final class ChatJsonCheck {
  /// Problems in one message. [roomId] is what your source passes to
  /// `Message.fromJson` for messages without a room id.
  static List<ChatJsonIssue> message(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
    String? roomId,
  }) {
    final issues = <ChatJsonIssue>[];
    _message(json, keys, roomId, '', issues);
    return issues;
  }

  /// Problems in one room, its members and its last message.
  static List<ChatJsonIssue> room(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
  }) {
    final issues = <ChatJsonIssue>[];
    final k = keys.roomKeys;
    final room = _try(issues, k.id, () => ChatRoom.fromJson(json, keys: keys));
    if (json[k.updatedAt] == null && json[k.lastMessage] is Map) {
      issues.add(
        ChatJsonIssue(
          k.updatedAt,
          'missing; the last message time is used. Send the last activity '
          'time so the inbox order is right after edits and new members.',
        ),
      );
    } else {
      _date(json, k.updatedAt, issues, '');
    }
    final members = readList(json[k.members]);
    if (members.isEmpty) {
      issues.add(
        ChatJsonIssue(
          k.members,
          "missing; read receipts (ticks) need each member's "
          '"${k.member.lastReadAt}", and direct rooms without a title show '
          "the other member's name.",
        ),
      );
    }
    for (final (i, m) in members.indexed) {
      if (m is Map) {
        _date(readMap(m), k.member.lastReadAt, issues, '${k.members}[$i].');
        _date(
          readMap(m),
          k.member.lastDeliveredAt,
          issues,
          '${k.members}[$i].',
        );
      }
    }
    final last = json[k.lastMessage];
    if (last is Map) {
      _message(
        readMap(last),
        keys,
        room?.id ?? readOptionalString(json[k.id]),
        '${k.lastMessage}.',
        issues,
      );
    }
    return issues;
  }

  /// Problems in one user, read with `keys.userKeys`.
  static List<ChatJsonIssue> user(
    Map<String, Object?> json, {
    ChatJsonKeys keys = const ChatJsonKeys(),
  }) {
    final issues = <ChatJsonIssue>[];
    final k = keys.userKeys;
    _try(issues, k.id, () => ChatUser.fromJson(json, keys: k));
    if (readOptionalString(json[k.name]) case null || '') {
      issues.add(
        ChatJsonIssue(
          k.name,
          'missing; the chat shows an empty name. Set '
          'UserJsonKeys(name: ...) if your API names it differently.',
        ),
      );
    }
    return issues;
  }

  static void _message(
    Map<String, Object?> json,
    ChatJsonKeys keys,
    String? roomId,
    String prefix,
    List<ChatJsonIssue> issues,
  ) {
    final start = issues.length;
    final message = _try(
      issues,
      '$prefix${keys.id}',
      () => Message.fromJson(json, keys: keys, roomId: roomId),
    );
    if (issues.length > start) return;

    for (final key in [keys.createdAt, keys.editedAt, keys.deletedAt]) {
      _date(json, key, issues, prefix);
    }

    if (json[keys.status] case final String status) {
      if (!MessageStatus.isKnown(status)) {
        issues.add(
          ChatJsonIssue(
            '$prefix${keys.status}',
            'unknown value "$status", read as sent. Use sent, delivered or '
                'seen (read and received are accepted too).',
          ),
        );
      } else if (MessageStatus.parse(status).isLocal) {
        issues.add(
          ChatJsonIssue(
            '$prefix${keys.status}',
            '"$status" only exists on the sending phone; the server should '
                'send sent, delivered or seen.',
          ),
        );
      }
    }

    switch (message) {
      case TextMessage(:final text) when text.isEmpty:
        issues.add(
          ChatJsonIssue(
            '$prefix${keys.text}',
            'empty or missing; set ChatJsonKeys(text: ...) if your API names '
                'it differently.',
          ),
        );
      case ImageMessage(:final images):
        _attachments(json, keys, images, prefix, issues, needsSize: true);
      case VideoMessage(:final video):
        _attachments(json, keys, [video], prefix, issues, needsSize: true);
      case AudioMessage(:final audio, :final duration):
        _attachments(json, keys, [audio], prefix, issues);
        if (duration == Duration.zero) {
          issues.add(
            ChatJsonIssue(
              '$prefix${keys.duration}',
              'missing; the voice message shows 0:00. Send the length in '
                  'milliseconds.',
            ),
          );
        }
      case FileMessage(:final file):
        _attachments(json, keys, [file], prefix, issues);
      case CustomMessage(:final customType):
        final raw = readOptionalString(json[keys.type]) ?? '';
        if (keys.resolveType(raw) != 'custom') {
          issues.add(
            ChatJsonIssue(
              '$prefix${keys.type}',
              'unknown type "$raw"; read as CustomMessage("$customType") '
                  'with the other fields as data. Draw it with '
                  'ChatBuilders.customBuilders["$customType"], or map it with '
                  'ChatJsonKeys(typeAliases: {"$raw": "text"}) if it is a kit '
                  'type under another name.',
            ),
          );
        }
      case _:
    }
  }

  static void _attachments(
    Map<String, Object?> json,
    ChatJsonKeys keys,
    List<Attachment> decoded,
    String prefix,
    List<ChatJsonIssue> issues, {
    bool needsSize = false,
  }) {
    final listed = readList(json[keys.attachments]);
    final raw = listed.isEmpty ? readList(json[keys.attachment]) : listed;
    final field = listed.isEmpty ? keys.attachment : keys.attachments;
    if (decoded.isEmpty) {
      issues.add(
        ChatJsonIssue(
          '$prefix$field',
          'no attachment; nothing to show. Send "${keys.attachments}" (a '
              'list) or "${keys.attachment}", as objects or URL strings.',
          isError: true,
        ),
      );
      return;
    }
    final ak = keys.attachmentKeys;
    for (final (i, a) in decoded.indexed) {
      final at = raw.length > 1 || listed.isNotEmpty
          ? '$prefix$field[$i]'
          : '$prefix$field';
      if (a.remoteUrl == null && a.localPath == null) {
        issues.add(
          ChatJsonIssue(
            at,
            'no URL; nothing to show. Set AttachmentJsonKeys(remoteUrl: ...) '
            'to your URL field.',
            isError: true,
          ),
        );
        continue;
      }
      final item = i < raw.length ? raw[i] : null;
      final hasMime = item is Map && item[ak.mimeType] != null;
      if (!hasMime) {
        issues.add(
          ChatJsonIssue(
            at,
            a.mimeType == Attachment.fallbackMimeType
                ? 'no "${ak.mimeType}" and no file extension; shown as a '
                      'file.'
                : 'no "${ak.mimeType}"; guessed ${a.mimeType}.',
          ),
        );
      }
      if (needsSize && a.aspectRatio == null) {
        issues.add(
          ChatJsonIssue(
            at,
            'no "${ak.width}" and "${ak.height}"; the bubble changes size '
            'when the media loads.',
          ),
        );
      }
    }
  }

  static void _date(
    Map<String, Object?> json,
    String key,
    List<ChatJsonIssue> issues,
    String prefix,
  ) {
    final value = json[key];
    final field = '$prefix$key';
    switch (value) {
      case final num n when n.abs() < epochSecondsLimit:
        issues.add(
          ChatJsonIssue(
            field,
            'read as epoch seconds (${readDate(n)!.toIso8601String()}). '
            'Epoch milliseconds or ISO-8601 avoid the guess.',
          ),
        );
      case final String s when num.tryParse(s) == null:
        if (DateTime.tryParse(s) == null) {
          issues.add(ChatJsonIssue(field, 'not a date: "$s".', isError: true));
        } else if (!_zone.hasMatch(s.trim())) {
          issues.add(
            ChatJsonIssue(
              field,
              'no time zone in "$s"; it is read as the phone\'s local time. '
              'End it with Z or an offset like +01:00.',
            ),
          );
        }
      case _:
    }
  }

  /// A time followed by `Z` or an offset; a bare date has no zone.
  static final _zone = RegExp(
    r':\d{2}(\.\d+)?\s*(Z|[+-]\d{2}(:?\d{2})?)$',
    caseSensitive: false,
  );

  static T? _try<T>(
    List<ChatJsonIssue> issues,
    String field,
    T Function() read,
  ) {
    try {
      return read();
    } on FormatException catch (e) {
      issues.add(ChatJsonIssue(field, e.message, isError: true));
    } on Object catch (e) {
      issues.add(ChatJsonIssue(field, 'cannot be read: $e', isError: true));
    }
    return null;
  }
}
