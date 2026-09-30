# Changelog

## [0.1.0] - 2026-09-30

First usable release: a backend-agnostic chat room and inbox with an offline
SQLite cache.

### Added

- Models: sealed `Message` hierarchy (text, image, video, audio, file, system, custom), `ChatRoom`, `RoomMember` read pointers, `Attachment`, keyset cursors, `ChatEvent`, and a configurable JSON codec (`ChatJsonKeys`, `MessageCodec`).
- Backend contracts `ChatSource`, `ChatUploader`, `ChatUserResolver`; `ChatKit` root, `ChatKitScope`, and `ChatConfig`.
- Customization surface: `ChatTheme` (`ThemeExtension` with `ColorScheme` fallback), `ChatStrings`, `ChatFormatters`, `ChatBuilders`, `InboxBuilders`, `MessageContext`, `GroupPosition`.
- Built-in SQLite cache: `ChatCache` interface and `DriftChatCache` (one database per user, reactive room and message queries, keyset paging, pending-to-confirmed reconciliation, outbox, drafts, sync state, retention). `ChatKit` opens and clears it.
- `ChatRepository`: cache-first sync with bounded gap fill, keyset paging in both directions, latest and detached `RoomWindow`s, jump to any message (`fetchAround` or paging back), ordered realtime events, reconnect resync, in-memory typing and presence, and batched user lookups with a TTL.
- `Outbox` and `RetryPolicy`: persistent, optimistic send, edit, delete and react, with upload progress, exponential backoff, failed state with retry or discard, per-room ordering, and resumption after restart. `ChatKit.setOnline` and `retryPending` drive it.
- Controllers: `InboxController` (pinned-first rooms, debounced search, paging, pin and mute, unread total), `ChatRoomController` (cached-first messages, paging, jump with highlight, new-message badge, read marking at the bottom, unread divider, seen-by and effective status, typing, media grouping, selection) and `ComposerController` (draft persistence, reply, edit, staged files, throttled typing). `ChatSource` gains optional `setPinned` and `setMuted`.
- `ChatMessageList`: a reversed, center-anchored `super_sliver_list` scroll engine that keeps the viewport stable when older pages, newer pages or incoming messages load; policy-based auto-scroll, scroll-to-bottom button with new-message badge, jump to any message with highlight, day separators, unread divider, floating date header, typing indicator and start-of-conversation marker. Also `MessageRow`, `ChatAvatar` and `buildChatListItems`.
- Message widgets: `MessageContent` (builder resolution: bubble → per type → default), `MessageBubble` with group-aware corners, `TextMessageView` (tappable links, e-mails and phones; read more; large emoji-only), `FileMessageView`, system, deleted and unsupported views, `StatusTicks` with semantics and retry, `ReplyPreview`, `ReactionsBar`, `MessageActionsSheet` with capability-filtered defaults and app actions, `SwipeToReply`, and selection mode in the list. `MessageContext` gains `currentUserId`, `repliedToAuthor`, `displayStatus` and `isSelectionMode`.
- Media and voice: `ChatMediaStore` keeps media on disk. It downloads each file once with progress, adopts the user's own uploads without a download, evicts LRU files past `ChatConfig.maxMediaCacheBytes`, exports with "Save" (`FilePicker` or `ChatKit.onSaveMedia`), and is cleared by `clearUserData`. Also new: `ChatImage`; `ImageMessageView` (1 to 4+ grid with "+N", size reserved before loading); `VideoMessageView`; `AudioMessageView` (waveform, seek, 1x / 1.5x / 2x); and `MediaViewer` (swipe, zoom, video playback, swipe-down to close, save). Plus `AudioPlayerHub` (one player at a time), `VoiceRecorderController` (permission, lock, review, discards under 1 s, 40-bar waveform) and `ChatMediaScope`. The cache schema moves to v2 with the `media_files` table.
- Composer: `ChatComposer`, with a send / hold-to-record button, Enter to send on desktop and web (Shift+Enter for a new line), Esc to cancel, and reply and edit banners (`ReplyEditBanner`). Also new: `AttachmentSheet` (with app options through `AttachmentOption`), `StagedAttachments`, and `VoiceRecordButton` (slide to cancel, slide up to lock, review with playback). `DefaultAttachmentPicker` and `attachmentFromXFile` read size, MIME type and dimensions. The pickers can be replaced through `AttachmentPicker`.
- Screens: `ChatRoomView` (app bar, optional header, message list and composer; owns a `ComposerController` when none is given), `ChatAppBar` with `ChatAppBarOptions` (app actions; subtitle shows typing, then presence, then member count), `SelectionAppBar` (copy, delete, forward callback), `InboxView` (search, pull to refresh, paging near the end, empty, loading and error states), `RoomTile`, `InboxSearchBar`, `RoomSwipeActions` (pin and mute) and `RoomAvatar`. A "Select" message action starts multi-selection. `InboxController.typingNames` and `ChatRepository.typingChanges` bring typing to the inbox.
- `ChatRoomView` applies `ChatBuilders.appBarActions`, `appBarBuilder` and `composerBuilder`. `ChatStrings.customPreview` gives custom message types an inbox and reply preview.
- Documentation: adapter guides for Firestore, Supabase and REST + WebSocket, a customization cookbook, a full README, the consumer agent skill, and an example app on an in-memory fake backend (offline toggle, random failures, custom offer message, 5 000-message room).

### Fixed

- Avatar and image load errors (for example HTTP 404) no longer reach `FlutterError.onError`; the placeholder is shown instead.

## [0.0.1] - 2026-09-30

### Added

- Package skeleton to reserve the name. No public API yet.
