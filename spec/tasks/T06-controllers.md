# T06 — Controllers

## Goal

Screen-level state for the inbox, a chat room and the composer, as plain `ChangeNotifier`s built on the repository and outbox. Widgets (T08+) only talk to these.

## Read first

- [../invariants.md](../invariants.md) (Lifecycle), [../decisions.md](../decisions.md) D6
- Family reference: `lemsa_core_kit` `Disposables`

## Depends on

T05.

## Deliverables

```text
lib/src/controllers/inbox_controller.dart
lib/src/controllers/chat_room_controller.dart
lib/src/controllers/composer_controller.dart
lib/src/controllers/chat_kit.dart            add inbox() / room(id) factories
test/controllers/*_test.dart
```

## Public API

```dart
class InboxController extends ChangeNotifier {
  List<ChatRoom> get rooms;          // pinned first, then updatedAt desc
  bool get isLoading; bool get hasMore; AppFailure? get failure;
  int get totalUnread;
  String get query; void search(String q);           // debounced by config.searchDebounce
  Future<void> refresh(); Future<void> loadMore();
  Future<void> setPinned(String roomId, {required bool pinned});
  Future<void> setMuted(String roomId, {required bool muted});
}

class ChatRoomController extends ChangeNotifier {
  String get roomId; ChatRoom? get room; String get currentUserId;
  List<Message> get messages;                        // newest first
  Map<String, ChatUser> get users;                   // authors resolved lazily
  bool get isLoadingOlder; bool get hasMoreOlder; bool get isDetached; AppFailure? get failure;
  Future<void> loadOlder(); Future<void> loadNewer(); Future<void> returnToLatest();
  Future<int?> jumpToMessage(String id);             // returns index once loaded
  ValueListenable<String?> get highlightedId;        // cleared after config.highlightDuration
  ValueListenable<int> get newMessagesCount;         // arrived while not at bottom
  MessageCursor? get unreadDividerCursor;            // first unread when the room opened
  List<String> get typingUserIds;
  List<RoomMember> seenBy(Message m);                // from read pointers, excluding author
  MessageStatus effectiveStatus(Message m);          // sent -> delivered -> seen from pointers

  Future<void> sendText(String text, {String? replyToId});
  Future<void> sendMedia(List<Attachment> files, {String? caption, String? replyToId});
  Future<void> sendVoice(Attachment audio, Duration duration, List<double> waveform, {String? replyToId});
  Future<void> sendCustom(String customType, Map<String, Object?> data, {String? replyToId});
  Future<void> edit(String id, String newText); Future<void> delete(String id);
  Future<void> react(String id, String emoji);       // toggles
  Future<void> retry(String localId); Future<void> discard(String localId);

  void onViewportChanged({required bool atBottom}); // list reports; drives markRead + badge
  ValueListenable<double?> progressOf(String localId);

  Set<String> get selectedIds; void toggleSelect(String id); void clearSelection();
}

class ComposerController extends ChangeNotifier {
  TextEditingController get text;
  Message? get replyTo; Message? get editing;
  List<Attachment> get staged;
  bool get canSend;
  void reply(Message m); void startEdit(Message m); void cancel();
  void stage(List<Attachment> files); void unstage(Attachment a);
  Future<void> submit();                              // calls ChatRoomController
  // Draft saved to cache (debounced) and restored on creation.
  // Typing: setTyping(true) at most every config.typingThrottle; false after config.typingTimeout idle or on submit.
}
```

## Done when

- [x] `ChatKit.inbox()` / `ChatKit.room(id)` return new controllers the caller disposes
- [x] Tests with fake source: inbox ordering and unread total; search debounce; room opens with cached messages first; `newMessagesCount` increments only when not at bottom; `markRead` called once when reaching bottom; `seenBy` from pointers in a 3-member group; typing throttle; draft persistence; edit and reply flows
- [x] All subscriptions/timers cancelled in `dispose` (test: no pending timers)

## As built

- `ChatSource` gained optional `setPinned(roomId, {pinned})` and `setMuted(roomId, {muted})` (no-ops in `ChatSourceDefaults`).
- `ChatRepository` gained `markRead` (cache pointer first, zeroes the room's `unreadCount`, then the source), `setRoomFlags` (optimistic pin / mute, reverted and rethrown on `AppFailure`), `setTyping`, and `presenceChanges`.
- `ChatKit.clock` (UTC time source) feeds the repository, the outbox and the controllers; tests replace it.
- `InboxController`: `hasLoadedCache`, `isLoadingMore`, `users`, `presenceOf(userId)`, `peerOf(room)` for direct rooms; peers and last-message authors are resolved lazily. Muted rooms are left out of `totalUnread`. A failed pin or mute sets `failure`.
- `ChatRoomController`:
  - `ready` completes once cached messages are shown and the first sync ended; `isSyncing`, `isLoadingNewer`, `isJumping`, `hasMoreNewer`, `hasLoadedCache`, `isAtBottom`, `members` added.
  - `messageById(id)` looks in the visible messages, then loads from the cache (for reply previews).
  - The window set by the first sync is dropped if the user already paged or jumped.
  - `markRead` goes to the newest confirmed message from others, once per newer message, only at the bottom of the latest window; the divider uses the read pointer captured before the first mark.
  - `sendMedia`: all images in one message, one message per video, audio or file; the caption goes on the first image or video message, else follows as a text; `replyToId` only on the first message; `ValidationFailure({'attachments': 'too_large'})` over `maxAttachmentBytes`. Sending from a detached window returns to the latest first.
  - `edit` changes text, or the caption of image and video messages. `discard` returns whether a message was removed.
  - Background lookups ignore results and errors after `dispose` (the kit may close right after).
- `ComposerController(room, {draftDebounce})`: `restored` future, `isEditing`, `isSubmitting`, `clearStaged`, static `canEdit`. `startEdit` accepts text, image and video messages and keeps the previous text, which comes back after the edit or `cancel` and is what the draft stores meanwhile. Typing uses `ChatKit.clock` for the throttle; errors are ignored.

## Do not

- Put widgets or `BuildContext` in controllers
- Scroll from controllers (the list owns scrolling; controllers expose state)
