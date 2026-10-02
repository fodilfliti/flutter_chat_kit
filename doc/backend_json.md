# Backend JSON

What `Message.fromJson`, `ChatRoom.fromJson`, `RoomMember.fromJson` and
`ChatUser.fromJson` read, what they forgive, and what your server receives
when the user sends. Use it as the contract when you write or adapt an API.

- If your backend is new, send exactly this shape and decode with the
  defaults.
- If your API already exists, keep it: rename fields with `ChatJsonKeys`
  (or the `ChatJsonKeys.camelCase` preset) and see
  [Plug in an existing API](adapters/your_api.md) for nested shapes.
- Check real responses with `ChatJsonCheck` (bottom of this page).

## The smallest valid message

```json
{ "id": "m1", "author_id": "u2", "created_at": "2026-09-30T12:00:00Z", "text": "Hi" }
```

`type` defaults to `text`. `room_id` can be left out when your source
passes it: `Message.fromJson(json, roomId: roomId)`. Everything else is
optional.

## Message fields (all types)

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | yes (or `local_id`) | Numbers are read as strings. |
| `local_id` | string | no | The client id of a message you sent; echo it back (see [Sending](#sending)). Falls back to `id`. |
| `room_id` | string | yes, unless passed as `roomId:` | |
| `author_id` | string | yes | The sender's user id. |
| `created_at` | date | yes | See [Value formats](#value-formats). |
| `type` | string | no | `text` (default), `image`, `video`, `audio`, `file`, `system`, `custom`, or your own name. |
| `status` | string | no | `sent` (default), `delivered`, `seen`. `read` and `received` are accepted too, in any case. |
| `edited_at` | date | no | Shows "edited". |
| `deleted_at` | date | no | Soft delete: the bubble shows "This message was deleted". |
| `reply_to_id` | string | no | The quoted message. |
| `reactions` | object | no | Emoji to user ids: `{"👍": ["u1", "u2"]}`. |
| `metadata` | object | no | Your extras, kept untouched. |
| `sent_by` | string | no | The staff member who wrote on behalf of a shared business profile. |

## Message types

**text**

```json
{ "type": "text", "text": "Hello" }
```

**image**: one or more images, with an optional caption.

```json
{
  "type": "image",
  "attachments": [
    { "remote_url": "https://cdn.example.com/a.jpg", "mime_type": "image/jpeg", "width": 1280, "height": 960 }
  ],
  "caption": "Sunset"
}
```

A single `attachment` object works too, and so do bare URL strings:
`"attachments": ["https://cdn.example.com/a.jpg"]`.

**video**, **file**

```json
{ "type": "video", "attachment": { "remote_url": "https://cdn.example.com/v.mp4", "thumbnail_url": "https://cdn.example.com/v.jpg", "width": 720, "height": 1280, "duration_ms": 8000 }, "caption": "Look" }
{ "type": "file", "attachment": { "remote_url": "https://cdn.example.com/report.pdf", "name": "report.pdf", "size": 24576 } }
```

`attachments: [...]` is accepted as well; the first item is used.

**audio** (voice notes)

```json
{ "type": "audio", "attachment": "https://cdn.example.com/voice.m4a", "duration_ms": 4200, "waveform": [0.1, 0.6, 0.3] }
```

`waveform` is optional (values from 0 to 1); without it a flat bar is drawn.

**system**: room events such as "Sara joined". The text comes from
`ChatStrings.system(code, args)`, so it can be translated. By default it
shows `args.text`, else the code.

```json
{ "type": "system", "code": "member_joined", "args": { "user_id": "u3", "text": "Sara joined" } }
```

**custom**: anything else (a location, an offer, a booking). Either
`custom_type` + `data`, or your own `type` name with its fields at the top
level; both decode to `CustomMessage`:

```json
{ "type": "custom", "custom_type": "location", "data": { "lat": 36.75, "lng": 3.06 } }
{ "type": "location", "lat": 36.75, "lng": 3.06 }
```

Draw it with `ChatBuilders.customBuilders` (see the README). To map your own
type names to kit types, use `ChatJsonKeys(typeAliases: {'photo': 'image'})`.

## Attachment

| Field | Type | Notes |
| --- | --- | --- |
| `remote_url` | string | Where to download it. `url` is read when `remote_url` is missing. |
| `mime_type` | string | Decides how it is shown. Guessed when missing (below). |
| `thumbnail_url` | string | A small image for previews and video posters. |
| `width`, `height` | int | Pixels; the bubble reserves its size before the image loads. |
| `duration_ms` | int | Video and audio length. |
| `size` | int | Bytes, shown for files. |
| `name` | string | File name, shown for files. |
| `local_path` | string | Only set by the kit on the sending device; ignore it on the server. |
| `thumbnail_path` | string | The video poster the kit made on the sending device; ignore it on the server. The kit uploads it and sends its URL as `thumbnail_url` when your uploader returns none. |

An attachment can be just a URL string: `"https://cdn.example.com/a.jpg"`.

**When `mime_type` is missing** it is guessed from the extension of the URL
(or the name), ignoring any `?query`: jpg, png, gif, webp, heic, mp4, mov,
webm, m4a, mp3, aac, ogg, opus, wav, pdf, Office files, txt and csv. A URL
without an extension takes the message type: `image/*` in an image message,
`video/*` in a video, `audio/*` in an audio message. A file message with no
extension becomes `application/octet-stream`, shown as a file.

## Room

```json
{
  "id": "r1",
  "type": "direct",
  "title": null,
  "avatar_url": null,
  "updated_at": "2026-09-30T12:00:00Z",
  "members": [
    { "user_id": "me", "role": "member", "last_read_at": "2026-09-30T12:00:00Z" },
    { "user_id": "u2", "last_read_at": "2026-09-30T11:58:00Z", "last_delivered_at": "2026-09-30T12:00:00Z" }
  ],
  "last_message": { "id": "m9", "author_id": "u2", "created_at": "2026-09-30T12:00:00Z", "text": "See you" },
  "unread_count": 2,
  "pinned": false,
  "muted": false,
  "labels": ["work"],
  "metadata": {}
}
```

| Field | Notes |
| --- | --- |
| `id` | Required. |
| `updated_at` | Last activity; the inbox sorts by it, newest first. Falls back to `last_message.created_at`. |
| `type` | `direct` (default), `group` or `channel`. |
| `title`, `avatar_url` | Leave them null for direct rooms: the kit shows the other member's name and photo. |
| `members` | Objects, or plain user ids: `["me", "u2"]`. |
| `members[].last_read_at`, `last_delivered_at` | Read pointers; the kit turns them into delivered and read ticks. |
| `members[].role` | `owner`, `admin` or `member` (default). |
| `last_message` | A message; its `room_id` can be left out. |
| `unread_count`, `pinned`, `muted`, `labels` | For the current user. `labels` can also be one string. |

## User

```json
{ "id": "u2", "name": "Sara", "avatar_url": "https://cdn.example.com/sara.jpg", "metadata": {} }
```

Only `id` is required, but without `name` the chat shows an empty name and
a blank avatar.

## Pages

`fetchRooms` and `fetchMessages` return a `ChatPage` that your source
builds. The kit doesn't read the page JSON itself, so any envelope works;
this one is what the guides use:

```json
{ "items": [ ... ], "has_more": true, "users": [ { "id": "u2", "name": "Sara" } ] }
```

- Items are **newest first**.
- `has_more` says whether an older page exists.
- `users` (optional) carries the people of the page (authors and members),
  so you don't need a `ChatUserResolver` for them.

## Value formats

| Value | Accepted | Recommended |
| --- | --- | --- |
| Dates | ISO-8601 string, epoch milliseconds, epoch seconds, a numeric string | ISO-8601 in UTC with `Z`: `2026-09-30T12:00:00Z` |
| Ids | strings or numbers | strings |
| Booleans | `true`/`false`, `1`/`0`, `"true"`/`"1"` | `true`/`false` |
| Durations | integer milliseconds | integer milliseconds |
| Lists | a list, or a single value where one item is meant | a list |

Numbers below 100 000 000 000 are read as **seconds**, larger ones as
milliseconds, so `1759233600` and `1759233600000` both mean the same moment.
An ISO date **without** `Z` or an offset is read in the phone's time zone,
so two users in different countries see different times; always add the
zone.

Everything the kit encodes uses ISO-8601 UTC dates and the field names
above.

## Sending

The kit creates the message on the device first (status `pending`), uploads
its files with your `ChatUploader`, then calls `ChatSource.send` with the
message. With the default codec, the body your server receives looks like:

```json
{
  "type": "image",
  "id": "5f0c1c6e-1d1b-4e5a-9a0e-6c2b7a1f9d10",
  "local_id": "5f0c1c6e-1d1b-4e5a-9a0e-6c2b7a1f9d10",
  "room_id": "r1",
  "author_id": "me",
  "created_at": "2026-09-30T12:00:00.000Z",
  "status": "sending",
  "attachments": [
    { "mime_type": "image/jpeg", "local_path": "/data/.../IMG_1.jpg", "remote_url": "https://cdn.example.com/IMG_1.jpg", "width": 1280, "height": 960, "size": 182044 }
  ],
  "caption": "Sunset"
}
```

On the server:

- **Make it idempotent by `local_id`.** The kit retries after timeouts and
  restarts, so the same message can arrive twice. Store `local_id` with a
  unique index and return the stored message the second time. With REST,
  `PUT /rooms/{roomId}/messages/{localId}` does this naturally.
- **Return the saved message** with your own `id` and `created_at`, and
  **echo `local_id`**. The kit replaces the pending bubble with it.
- Echo `local_id` in your realtime events too, so the sender's own copy
  matches the bubble already on screen.
- Ignore `status` and `local_path`; they only mean something on the device.
- `id` equals `local_id` until you assign your own.

## Minimum vs nice to have

The required fields give a working chat. Each optional one turns on
something visible:

| Without | What you lose |
| --- | --- |
| `room_id` on messages | Nothing, if your source passes `roomId:`. |
| `status`, member read pointers | Your messages stay at one tick: no delivered or read ticks. |
| `members` | Direct rooms have no peer name or photo, groups no member count, no read ticks. |
| `users` on pages (or a `ChatUserResolver`) | No names in direct rooms and groups, and blank avatars. |
| `mime_type` | Guessed from the extension; an extension-less URL in a file message shows as a file. |
| `width` / `height` | Images and videos jump in size when they load, and the list can shift. |
| `thumbnail_url` | Videos sent from Android, iOS or the web carry the poster the kit made and uploaded; other videos have no poster. Previews load the full image. |
| `duration_ms` (audio) | The voice note shows 0:00 until it plays. |
| `updated_at` | The last message time is used; the order is off when a room changes without a new message. |
| `unread_count` | No unread badges in the inbox. |
| `local_id` echo | Your own message can appear twice for a moment, until the send response arrives. |

## Other field names: `ChatJsonKeys`

Rename only what differs. The nested sets cover attachments
(`AttachmentJsonKeys`), rooms (`RoomJsonKeys`), room members
(`MemberJsonKeys`, inside `RoomJsonKeys.member`) and users
(`UserJsonKeys`):

```dart
const keys = ChatJsonKeys(
  authorId: 'sender_id',
  createdAt: 'sent_at',
  typeAliases: {'photo': 'image', 'voice': 'audio'},
  attachmentKeys: AttachmentJsonKeys(remoteUrl: 'file_url'),
  roomKeys: RoomJsonKeys(updatedAt: 'last_activity_at'),
);

final message = Message.fromJson(json, keys: keys, roomId: roomId);
final room = ChatRoom.fromJson(json, keys: keys);
final user = ChatUser.fromJson(json, keys: keys.userKeys);
```

For a camelCase API, use the preset:

```dart
final message = Message.fromJson(json, keys: ChatJsonKeys.camelCase);
```

| Default | `camelCase` |
| --- | --- |
| `local_id`, `room_id`, `author_id` | `localId`, `roomId`, `authorId` |
| `created_at`, `edited_at`, `deleted_at` | `createdAt`, `editedAt`, `deletedAt` |
| `reply_to_id`, `sent_by`, `custom_type` | `replyToId`, `sentBy`, `customType` |
| `duration_ms` (message and attachment) | `durationMs` |
| `mime_type`, `local_path`, `remote_url`, `thumbnail_url`, `thumbnail_path` | `mimeType`, `localPath`, `remoteUrl`, `thumbnailUrl`, `thumbnailPath` |
| `avatar_url`, `updated_at`, `last_message`, `unread_count` | `avatarUrl`, `updatedAt`, `lastMessage`, `unreadCount` |
| `user_id`, `last_read_at`, `last_delivered_at` | `userId`, `lastReadAt`, `lastDeliveredAt` |

Tweak the preset when one name differs:

```dart
const keys = ChatJsonKeys(
  localId: 'localId',
  roomId: 'roomId',
  authorId: 'senderId', // the only difference
  createdAt: 'createdAt',
  editedAt: 'editedAt',
  deletedAt: 'deletedAt',
  replyToId: 'replyToId',
  sentBy: 'sentBy',
  duration: 'durationMs',
  customType: 'customType',
  attachmentKeys: AttachmentJsonKeys.camelCase,
  roomKeys: RoomJsonKeys.camelCase,
  userKeys: UserJsonKeys.camelCase,
);
```

To send in your format, encode with the same keys:
`MessageCodec(keys: keys).encode(message)`. The kit's own cache always uses
the defaults, so changing keys never needs a migration.

When a field is nested (`"sender": {"id": ...}`) or split differently, keys
are not enough; reshape the map first. See
[Plug in an existing API](adapters/your_api.md#3-read-your-json).

## Check your JSON: `ChatJsonCheck`

Save a real response from your API and check it once in a test. Each issue
names the field and the fix; errors mean decoding fails, warnings mean it
works with a guess or with something missing on screen.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('my API JSON fits the kit', () {
    final json = jsonDecode(File('test/fixtures/messages.json')
        .readAsStringSync()) as Map<String, Object?>;
    for (final item in json['items']! as List) {
      final issues = ChatJsonCheck.message(
        item as Map<String, Object?>,
        keys: ChatJsonKeys.camelCase,
        roomId: 'r1',
      );
      expect(issues, isEmpty, reason: issues.join('\n'));
    }
  });
}
```

`ChatJsonCheck.room(json, keys: ...)` and `ChatJsonCheck.user(json, keys:
...)` work the same way. Typical findings:

```text
warning created_at: read as epoch seconds (2025-09-30T12:00:00.000Z). Epoch milliseconds or ISO-8601 avoid the guess.
warning attachments[0]: no "mime_type"; guessed image/jpeg.
warning attachments[0]: no "width" and "height"; the bubble changes size when the media loads.
warning type: unknown type "location"; read as CustomMessage("location") with the other fields as data. ...
error id: Message "m1": missing "author_id". Set ChatJsonKeys(authorId: ...) to the field holding the sender id, ...
```
