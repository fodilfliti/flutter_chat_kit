# flutter_chat_kit

[![pub package](https://img.shields.io/pub/v/flutter_chat_kit.svg)](https://pub.dev/packages/flutter_chat_kit)

Backend-agnostic chat for Flutter. You implement one `ChatSource` for your backend (Firebase, Supabase, REST, WebSocket, ...); the kit owns the models, the SQLite cache, the offline outbox, the controllers, and a chat room and inbox UI you can customize piece by piece.

> **Status:** 0.0.1 is a name reservation. The API is being built; nothing is exported yet.

**Platforms:** Android, iOS, Linux, macOS, Web, Windows  
**Requires:** Flutter `>=3.44.0`

## Install

```yaml
dependencies:
  flutter_chat_kit: ^0.0.1
```

```dart
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
```

## Owns (planned for 0.1.0)

- Typed models: `Message` (text, image, video, audio, file, system, custom), `ChatRoom`, `RoomMember`, `ChatUser`, `Attachment`
- `ChatSource` / `ChatUploader` / `ChatUserResolver` contracts that the app implements
- Built-in Drift (SQLite) cache, per-room sync, keyset pagination, offline outbox with retry
- `ChatKit`, `InboxController`, `ChatRoomController`, `ComposerController`
- `ChatRoomView`, `InboxView`, and every sub-widget, replaceable through `ChatBuilders`
- Direct and group chats, replies, reactions, read receipts, typing, voice messages, media gallery

Strings are passed by the app (`ChatStrings`); the kit never localizes.

## Agent skill

```bash
npx skills add fodilfliti/flutter_chat_kit
# or: npx skills add fodilfliti/lemsa-skills
```

## Links

- [GitHub](https://github.com/fodilfliti/flutter_chat_kit)
- [Lemsa skills](https://github.com/fodilfliti/lemsa-skills)
