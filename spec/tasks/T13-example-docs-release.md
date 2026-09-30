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
skills/flutter-chat-kit/SKILL.md            full consumer skill (no links to spec/)
CHANGELOG.md                                [0.1.0]
```

## Done when

- [ ] Example runs on Android, iOS, web, Windows: inbox → room, send text/image/voice, custom offer card, jump to replied message, offline toggle queues then flushes
- [ ] Adapter guides compile-checked snippets (paste into a scratch app)
- [ ] `fvm flutter analyze`, `fvm flutter test` green; `dart pub publish --dry-run` clean
- [ ] Family table in `skills/spec/package.md` updated to 0.1.0

## Do not

- Add backend SDKs to the package `pubspec.yaml` (only in guides; the example uses fakes)
- Publish without the owner's go-ahead
