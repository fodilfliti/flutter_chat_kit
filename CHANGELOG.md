# Changelog

## [Unreleased]

### Added

- Models: sealed `Message` hierarchy (text, image, video, audio, file, system, custom), `ChatRoom`, `RoomMember` read pointers, `Attachment`, keyset cursors, `ChatEvent`, and a configurable JSON codec (`ChatJsonKeys`, `MessageCodec`).
- Backend contracts `ChatSource`, `ChatUploader`, `ChatUserResolver`; `ChatKit` root, `ChatKitScope`, and `ChatConfig`.
- Customization surface: `ChatTheme` (`ThemeExtension` with `ColorScheme` fallback), `ChatStrings`, `ChatFormatters`, `ChatBuilders`, `InboxBuilders`, `MessageContext`, `GroupPosition`.
- Built-in SQLite cache: `ChatCache` interface and `DriftChatCache` (one database per user, reactive room and message queries, keyset paging, pending-to-confirmed reconciliation, outbox, drafts, sync state, retention). `ChatKit` opens and clears it.

## [0.0.1] - 2026-09-30

### Added

- Package skeleton to reserve the name. No public API yet; see `spec/tasks/` for the build order.
