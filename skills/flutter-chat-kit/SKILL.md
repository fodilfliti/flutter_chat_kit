---
name: flutter-chat-kit
description: >
  Use flutter_chat_kit to build chat screens: a chat room page, an inbox
  (conversation list), direct and group chats, media and voice messages,
  replies, reactions, read receipts, offline cache and outbox. Activate when
  implementing a ChatSource for Firebase, Supabase or REST, customizing message
  bubbles, adding custom message types (offers, cards), or adding app bar
  actions to a chat page — not for backend SDK code inside the kit, Riverpod
  inside the kit, or localizing inside the kit.
license: MIT
metadata:
  author: fodilfliti
  version: "0.0.1"
  homepage: https://pub.dev/packages/flutter_chat_kit
---

# flutter_chat_kit (consumer)

> Stub. The full consumer guide is written in task T13, once the API exists.

## When to import

```dart
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
```

Use this package for:

- A chat room page and an inbox that work offline (built-in SQLite cache)
- Any backend: implement `ChatSource`, `ChatUploader`, `ChatUserResolver` in the app
- Custom message types through `CustomMessage` + `ChatBuilders.customBuilders`
- Replacing any piece of the UI (bubble, app bar, composer, tiles) through builders

## Rules

- Map backend DTOs to kit models inside your `ChatSource`. Throw `AppFailure`, never vendor exceptions.
- `send` must be idempotent on `localId`.
- Pass translated text through `ChatStrings`; the kit never localizes.
- Call `ChatKit.clearUserData()` on sign-out.

## Do not put in chat_kit

| Concern | Where |
| --- | --- |
| Firebase / Supabase / REST calls | app `ChatSource` implementation |
| File storage upload | app `ChatUploader` implementation |
| Riverpod providers | app (wrap `ChatKit` / controllers) |
| Translated strings | app, via `ChatStrings` |
| Push notifications | app |
