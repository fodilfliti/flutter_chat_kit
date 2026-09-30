# flutter_chat_kit example

A complete chat app on an in-memory fake backend. No accounts, keys or
server are needed; replies, receipts, typing and presence are simulated.

## Run

```bash
flutter pub get
flutter run            # any device: Android, iOS, macOS, Windows, Linux
```

For the web, first copy `sqlite3.wasm` (from the
[sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases),
matching the `sqlite3` version in `pubspec.lock`) and `drift_worker.js`
(from the [drift releases](https://github.com/simolus3/drift/releases),
matching `drift`) into `web/`, then run `flutter run -d chrome`.

## What to try

- **Inbox**: unread badges, a muted and a pinned room, a group with
  stacked avatars, search, swipe a row for pin and mute, long-press for the
  same actions. The title shows the total unread count.
- **Direct chat with Amina**: send a message and watch it go from pending to
  sent, delivered and read; Amina then types and replies. Her online state
  shows in the app bar.
- **Offline**: tap the cloud button to go offline, send messages (they
  appear at once as pending), go back online and they are delivered in
  order. The history stays available offline from the SQLite cache.
- **Random send failures**: enable it in the inbox menu; failed messages
  show a retry action in their bubble and long-press menu.
- **Media and voice**: attach photos, videos or files, or hold the mic
  button to record (slide to cancel, slide up to lock). Tap an image to open
  the viewer and save it.
- **Custom message**: in "Weekend trip", tap the offer button (app bar or
  attachment sheet) to send an offer card; the other side can accept or
  decline. The inbox preview uses `ChatStrings.customPreview`.
- **Big history**: "Big history (5 000 messages)" pages smoothly in both
  directions; tap a reply preview to jump to a much older message.
- **Selection**: long-press a message and choose "Select" to copy, delete or
  forward several messages.

## Where to look

| File | Shows |
| --- | --- |
| `lib/fake/fake_chat_source.dart` | a complete `ChatSource`: keyset pages, idempotent send, events |
| `lib/fake/fake_uploader.dart` | a `ChatUploader` with progress |
| `lib/offer/offer_card.dart` | a custom message type, its builder, preview and attachment option |
| `lib/backend.dart` | creating and opening `ChatKit`, connectivity, strings |
| `lib/pages/inbox_page.dart` | `InboxView` inside your own `Scaffold` |
| `lib/pages/room_page.dart` | `ChatRoomView` with header, app bar actions and forward |

To use a real backend, replace `FakeChatSource` with your own `ChatSource`;
see the adapter guides in the package's `doc/adapters/` folder.
