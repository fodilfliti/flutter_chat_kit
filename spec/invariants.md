# Invariants

## Exports and dependencies

- Public export **only** via `lib/flutter_chat_pro.dart`.
- No backend SDK in `lib/`: no `firebase_*`, `cloud_firestore`, `supabase*`, `dio`. Enforced by `test/import_guard_test.dart` (from T02).
- No Riverpod, slang, easy_localization, or `.tr(` in `lib/`.
- The only Lemsa kit dependency is `lemsa_core_kit`.
- Flutter `>=3.44.0`. Third-party packages at their latest stable version; `flutter pub outdated` shows no direct dependency behind at release (D10).

## Data

- Models are immutable, have value equality and `copyWith`, and round-trip through `toJson` / `fromJson`.
- Every message has a client `localId` (uuid v4) from creation. It is the widget key and the idempotency key for `send`. It never changes.
- `id` equals `localId` until the server confirms; afterwards it is the server id. Lookups try `localId`, then `id`.
- Server `createdAt` replaces the client time on confirmation.
- Pagination uses keyset cursors `(createdAt, id)`. No offset paging, no growing limits.
- Sync state is **per room** (`room_sync_state`). There is no global "last synced" key.
- Read receipts come from `RoomMember.lastReadAt` / `lastDeliveredAt` pointers, not per-message flags.

## Cache and sync

- The UI reads only from the cache (Drift `watch` streams). Only the repository and outbox write to it.
- Widgets never call `ChatSource` or `ChatUploader`.
- Every message received by fetch, realtime event, or send is written to the cache before it reaches the UI.
- One database file per user: `chat_kit_<userId>.sqlite`. `ChatKit` owns it; screens never close it.
- `ChatKit.clearUserData()` deletes the user's cache and outbox.
- Pending sends live in the `outbox` table and survive restarts.
- A failed send ends in `MessageStatus.failed` with retry and delete available. Never a spinner forever.
- Sources throw `AppFailure`; the kit catches at the repository/outbox boundary. `empty_catches` is an error.

## UI

- Kits never localize: user-facing text comes from `ChatStrings` (English defaults), formats from `ChatFormatters`. No string literal is shown to the user from `lib/` (D12).
- Media is read from local files first (`ChatMediaStore`, D11). Sent files are adopted into the store; received ones are downloaded once.
- Every builder receives the default child (or default list of actions) so apps can wrap.
- The message list is reversed (index 0 = newest). Loading older messages must not move the viewport.
- New messages auto-scroll only per `ChatConfig.autoScrollPolicy`; otherwise the unread badge increments.
- Per-message progress (upload, audio position) is exposed as `ValueListenable` and must not rebuild the whole list.
- Images reserve their aspect ratio from `Attachment.width` / `height` before loading.
- Only one voice message plays at a time (`AudioPlayerHub`).

## Lifecycle

- Controllers are `ChangeNotifier`. Whoever creates a controller disposes it. `ChatKit.room(id)` returns a controller the caller disposes.
- Stream subscriptions and timers are cancelled in `dispose()`.
