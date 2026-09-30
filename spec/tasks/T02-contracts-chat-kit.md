# T02 — Contracts, ChatKit root, ChatKitScope

## Goal

Define what the app implements (backend contract) and the single root object apps create. After this task an app can compile against the kit's public shape even though cache and sync are stubs.

## Read first

- [../package.md](../package.md) (Public surface), [../decisions.md](../decisions.md) D1, D6
- `lemsa_core_kit`: `AppFailure` family

## Depends on

T01.

## Deliverables

```text
lib/src/source/chat_source.dart
lib/src/source/chat_uploader.dart        ChatUploader, UploadProgress
lib/src/source/chat_user_resolver.dart
lib/src/controllers/chat_kit.dart        ChatKit (open/close/clearUserData; room()/inbox() added in T06)
lib/src/controllers/chat_kit_scope.dart  ChatKitScope (InheritedWidget) + context.chatKit
test/import_guard_test.dart
test/source/fake_chat_source.dart        in-memory ChatSource used by later tests
```

## Public API

```dart
abstract interface class ChatSource {
  Future<ChatPage<ChatRoom>> fetchRooms({RoomCursor? after, int limit = 20, String? search});
  Future<ChatPage<Message>> fetchMessages(String roomId,
      {MessageCursor? before, MessageCursor? after, int limit = 30}); // newest first
  // null = unsupported; the kit falls back to paging older until found.
  Future<ChatPage<Message>?> fetchAround(String roomId, String messageId, {int limit = 30});
  Stream<ChatEvent> events({String? roomId}); // roomId null = inbox-level events
  Future<Message> send(Message pending);      // idempotent on localId; returns confirmed message
  Future<Message> edit(Message message);
  Future<void> delete(String roomId, String messageId);
  Future<void> markRead(String roomId, MessageCursor upTo);
  Future<void> setTyping(String roomId, {required bool typing});
  Future<void> react(String roomId, String messageId, String emoji, {required bool add});
}

/// Optional capabilities: implement with `with ChatSourceDefaults` to get no-op
/// setTyping / react and a null (unsupported) fetchAround.
mixin ChatSourceDefaults implements ChatSource { ... }

sealed class UploadProgress {}
final class UploadRunning extends UploadProgress { final double fraction; } // 0..1
final class UploadDone extends UploadProgress { final String remoteUrl; final String? thumbnailUrl; }

abstract interface class ChatUploader {
  Stream<UploadProgress> upload(Attachment attachment, {required String roomId, required String localId});
}

abstract interface class ChatUserResolver {
  Future<List<ChatUser>> resolve(Set<String> ids);
}

class ChatKit extends ChangeNotifier {
  ChatKit({
    required String currentUserId,
    required ChatSource source,
    ChatUploader? uploader,           // null = media sending disabled
    ChatUserResolver? users,
    ChatConfig config = const ChatConfig(),   // full ChatConfig landed here
    ChatCache? cache,                 // added in T03; default DriftChatCache
  });
  String get currentUserId;
  bool get isOpen;
  bool get isOnline;
  Future<void> open();                // opens cache, starts outbox (T05)
  Future<void> close();
  Future<void> clearUserData();       // wipes this user's DB
  void setOnline({required bool online}); // app feeds connectivity
  Future<void> retryPending();
}

class ChatKitScope extends InheritedNotifier<ChatKit> {
  static ChatKit of(BuildContext context);
  static ChatKit? maybeOf(BuildContext context);
}
extension ChatKitContext on BuildContext { ChatKit get chatKit; }
```

Contract docs (dartdoc on `ChatSource`) must state:

- Methods throw `AppFailure`, never vendor exceptions.
- `fetchMessages` returns newest first; `before` is exclusive; `after` is exclusive.
- `send` must be idempotent on `localId` (for example, use `localId` as the document id / primary key).
- `events` must emit the sender's own confirmed messages too; the kit deduplicates.

## Done when

- [x] Contracts, `ChatKit`, `ChatKitScope` exported
- [x] `FakeChatSource` (in test/) supports paging, events via `StreamController`, failures on demand
- [x] `import_guard_test.dart` scans `lib/` and fails on `firebase_`, `cloud_firestore`, `supabase`, `package:dio`, `riverpod`, `slang`, `easy_localization`, `.tr(`
- [x] Widget test: `ChatKitScope.of` finds the kit; `maybeOf` returns null outside
- [x] Analyze clean

## Do not

- Add backend helpers (Firestore converters, Supabase queries) to `lib/`
- Make `ChatKit` a singleton or global
