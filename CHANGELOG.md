# Changelog

## [Unreleased]

### Added

- Models: sealed `Message` hierarchy (text, image, video, audio, file, system, custom), `ChatRoom`, `RoomMember` read pointers, `Attachment`, keyset cursors, `ChatEvent`, and a configurable JSON codec (`ChatJsonKeys`, `MessageCodec`).
- Backend contracts `ChatSource`, `ChatUploader`, `ChatUserResolver`; `ChatKit` root, `ChatKitScope`, and `ChatConfig`.
- Customization surface: `ChatTheme` (`ThemeExtension` with `ColorScheme` fallback), `ChatStrings`, `ChatFormatters`, `ChatBuilders`, `InboxBuilders`, `MessageContext`, `GroupPosition`.
- Built-in SQLite cache: `ChatCache` interface and `DriftChatCache` (one database per user, reactive room and message queries, keyset paging, pending-to-confirmed reconciliation, outbox, drafts, sync state, retention). `ChatKit` opens and clears it.
- `ChatRepository`: cache-first sync with bounded gap fill, keyset paging in both directions, latest and detached `RoomWindow`s, jump to any message (`fetchAround` or paging back), ordered realtime events, reconnect resync, in-memory typing and presence, and batched user lookups with a TTL.
- `Outbox` and `RetryPolicy`: persistent, optimistic send, edit, delete and react, with upload progress, exponential backoff, failed state with retry or discard, per-room ordering, and resumption after restart. `ChatKit.setOnline` and `retryPending` drive it.
- Controllers: `InboxController` (pinned-first rooms, debounced search, paging, pin and mute, unread total), `ChatRoomController` (cached-first messages, paging, jump with highlight, new-message badge, read marking at the bottom, unread divider, seen-by and effective status, typing, media grouping, selection) and `ComposerController` (draft persistence, reply, edit, staged files, throttled typing). `ChatSource` gains optional `setPinned` and `setMuted`.
- `ChatMessageList`: a reversed, center-anchored `super_sliver_list` scroll engine that keeps the viewport stable when older pages, newer pages or incoming messages load; policy-based auto-scroll, scroll-to-bottom button with new-message badge, jump to any message with highlight, day separators, unread divider, floating date header, typing indicator and start-of-conversation marker. Also `MessageRow`, `ChatAvatar` and `buildChatListItems`.

## [0.0.1] - 2026-09-30

### Added

- Package skeleton to reserve the name. No public API yet; see `spec/tasks/` for the build order.
