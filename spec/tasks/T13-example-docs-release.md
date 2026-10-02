# T13 — Example, adapter guides, release 0.1.0

## Goal

Prove the kit end to end with a fake backend, show how to plug real backends, and publish 0.1.0.

## Read first

- [../package.md](../package.md); the family `lemsa-package-author` skill (`skills/skills/lemsa-package-author/SKILL.md`) for README / SKILL.md format

## Depends on

T12.

## Deliverables

```text
example/lib/main.dart
example/lib/fake/fake_chat_source.dart      direct + group rooms, 5 000-message room, simulated realtime replies, typing, receipts, random failures toggle
example/lib/fake/fake_uploader.dart         simulated progress
example/lib/offer/offer_card.dart           CustomMessage('offer') builder + "Offer" attachment option + app bar action
example/lib/pages/{inbox_page,room_page}.dart
doc/adapters/firestore.md                   collections layout, localId as doc id, snapshots -> ChatEvent, markRead via member doc
doc/adapters/supabase.md                    tables + RPC, realtime channel -> ChatEvent, presence/broadcast for typing
doc/adapters/rest_websocket.md              endpoints, cursor params, WebSocket event mapping
doc/customization.md                        builders cookbook (bubble, custom type, app bar actions, theme)
README.md                                   full: install, 20-line quick start, platform setup, customization, links
skills/flutter-chat-pro/SKILL.md            full consumer skill (no links to spec/)
CHANGELOG.md                                [0.1.0]
```

## Done when

- [ ] Example runs on Android, iOS, web, Windows: inbox → room, send text/image/voice, custom offer card, jump to replied message, offline toggle queues then flushes (Windows debug build and web build compile; the example widget test opens the inbox, the group and its offer card; manual device runs still to do)
- [x] Adapter guides compile-checked snippets (paste into a scratch app)
- [x] `fvm flutter analyze`, `fvm flutter test` green; `dart pub publish --dry-run` clean
- [x] Family table in `skills/spec/package.md` updated to 0.1.0

## As built

- **Example.** Platforms android, ios, web, windows, macos, linux with microphone, camera and photo permissions (Android manifest, iOS and macOS `Info.plist`, macOS entitlements). `FakeChatSource` keeps everything in memory: four rooms (direct with unread, muted direct, pinned group with a system message and an offer, and a 5 000-message group whose messages reply to older ones), idempotent `send`, soft delete, simulated receipts, typing and replies, an `online` switch and a random-failures switch. `ExampleBackend` wires the source, `FakeUploader` and `ChatKit`; `OfflineBanner` and `ConnectionButton` drive `ChatKit.setOnline`. The offer lives in `offer/offer_card.dart`: `customPreview`, the `customBuilders` entry, the attachment option and the app bar action. `test/example_test.dart` runs the app on an in-memory Drift database.
- **Kit changes found while building the example.** `ChatRoomView` now applies `ChatBuilders.appBarActions`, `appBarBuilder` (room bar only) and `composerBuilder`; its own `composerBuilder` parameter is gone. `ChatAppBarOptions.copyWith`. `ChatStrings.customPreview(customType, data)` feeds `MessageSnippet` (inbox and reply previews). `ChatAvatar` and `ChatImage` pass an `errorListener` so failed network images show the placeholder instead of reaching `FlutterError.onError`.
- **Docs.** The adapter guides (`doc/adapters/`) were pasted into a scratch app with `cloud_firestore` 6.10, `firebase_storage` 13.6, `supabase_flutter` 2.18, `http` 1.6 and `web_socket_channel` 3.0 and analyze clean. That check found that `supabase_flutter` exports its own `Presence`, so the Supabase guide imports it with `hide Presence`. The customization cookbook snippets were checked the same way. The library doc no longer points to `spec/`, which is not published.
- **Release.** Version 0.1.0 in `pubspec.yaml`, `CHANGELOG.md` and the skill metadata. Not published: waiting for the owner's go-ahead.

## Do not

- Add backend SDKs to the package `pubspec.yaml` (only in guides; the example uses fakes)
- Publish without the owner's go-ahead
