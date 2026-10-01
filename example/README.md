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
- **Incoming messages**: tap the chat bubble button (inbox or room) and
  people start writing to you on their own, like in a busy real app: every
  few seconds someone in one of the chats types for a moment, then a text
  or a photo arrives. Unread badges, the inbox order, typing and the open
  room all update live. On the shop profile it is customers asking
  questions. Tap again to stop.
- **Media and voice**: attach photos, videos or files, or hold the mic
  button to record (slide to cancel, slide up to lock). Tap an image to open
  the viewer and save it.
- **Chat style**: tap the palette button (inbox or room) to open a live
  style sheet. Pick a preset (Classic, WhatsApp, WhatsApp new, Telegram,
  iMessage, Messenger, Minimal, Cards, Glass), a color and dark mode, then
  drag the scale, text size, message font size and bubble radius sliders,
  toggle grey text, shadows, borders and square avatars, and switch inbox
  rows between plain, lines and cards. The screen behind the sheet updates
  as you go. "Random style" picks a new look in one tap.
- **Style shuffle**: tap the shuffle button (inbox or room) and the chat
  changes look every 4 seconds: the next preset, a new color, sometimes
  dark mode, and random bubble and row shapes. Made for recording a demo
  that shows every look; tap again to stop. Reset demo stops it too.
- **Custom messages**: in "Weekend trip", tap the offer button (app bar or
  attachment sheet) to send a product offer; the other side can accept or
  decline. In "Lemsa Shop", the same `offer` type shows as a quote with line
  items, and a booking sits inside a regular bubble with its time and
  ticks. The attachment sheet sends all three. The inbox preview uses
  `ChatStrings.customPreview`.
- **Big history**: "Big history (5 000 messages)" pages smoothly in both
  directions; tap a reply preview to jump to a much older message.
- **Selection**: long-press a message and choose "Select" to copy, delete or
  forward several messages.
- **Languages**: tap the translate button (inbox or room) and pick English,
  Français or العربية. Every chat text, the example's own screens, the
  custom cards, plurals ("4 أعضاء", "4 membres") and dates follow at once,
  and Arabic turns the whole app right to left. Messages from the fake
  backend stay as they were written; system messages are translated from
  their code.
- **Reset demo**: in the inbox menu (three dots), "Reset demo" puts
  everything back as on first launch, so a demo can be recorded again and
  again. Every profile's cache, drafts, queued messages and media are
  deleted, the fake backend starts over with its sample chats, the
  connection comes back, incoming messages and random failures turn off,
  the personal profile is active and the style returns to Classic with the
  default color, light mode and scale. The language stays as picked.

## Translations (slang)

The texts live in `lib/i18n/en.i18n.json`, `fr.i18n.json` and
`ar.i18n.json`. After editing them, regenerate the code:

```bash
dart run slang
```

`lib/i18n/chat_strings.dart` turns the `chat` section into a full
`ChatStrings`. `test/translation_test.dart` checks that no chat text is
left in English in Arabic, that only real look-alikes stay the same in
French, and that switching the language updates the running app.

## Where to look

| File | Shows |
| --- | --- |
| `lib/fake/fake_chat_source.dart` | a complete `ChatSource`: keyset pages, idempotent send, events |
| `lib/fake/fake_uploader.dart` | a `ChatUploader` with progress |
| `lib/style/style_settings.dart` | presets and live overrides turned into a `ChatTheme` (scale applied last) |
| `lib/style/style_sheet.dart` | the live style sheet |
| `lib/custom/custom_messages.dart` | custom types: the `customBuilder` resolver for variants, `bubbledCustomTypes`, previews, attachment options |
| `lib/custom/offer_cards.dart`, `booking_card.dart` | cards that follow the chat theme and scale |
| `lib/backend.dart` | creating and opening `ChatKit`, connectivity |
| `lib/i18n/` | slang translations, `ChatStrings` from them, the language button |
| `lib/pages/inbox_page.dart` | `InboxView` inside your own `Scaffold` |
| `lib/pages/room_page.dart` | `ChatRoomView` with header, app bar actions and forward |

To use a real backend, replace `FakeChatSource` with your own `ChatSource`;
see the adapter guides in the package's `doc/adapters/` folder.
