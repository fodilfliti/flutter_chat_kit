# T05 — Outbox (sending, retry, reconciliation)

## Goal

Every write (send, edit, delete, react) goes through a persistent queue. The user sees their message instantly, progress for media, and a clear failed state with retry.

## Read first

- [../invariants.md](../invariants.md) (Data, Cache and sync)
- valizex `contact_chat_page.dart` `_uploadImage` / `_uploadVideo` (good: `localId` + progress; bad: rows never persisted, no retry)
- lightnessword `sendMessaget` (good: client UUID used as server id)

## Depends on

T04.

## Deliverables

```text
lib/src/sync/outbox.dart
lib/src/sync/outbox_entry.dart       already landed in T03 (OutboxEntry, OutboxOp; keyed by `key`, e.g. `send:<localId>`)
lib/src/sync/retry_policy.dart       exponential backoff with jitter, maxAttempts
test/sync/outbox_test.dart
```

## Public API

```dart
class Outbox {
  Outbox({required ChatSource source, required ChatUploader? uploader, required ChatCache cache, required RetryPolicy retry});
  Future<Message> send(Message pending);      // writes cache (status: pending) + outbox, then runs
  Future<void> edit(Message message);
  Future<void> delete(String roomId, String idOrLocalId);
  Future<void> react(String roomId, String idOrLocalId, String emoji, {required bool add});
  Future<void> retry(String localId);         // failed -> pending, run now
  Future<void> discard(String localId);       // remove failed message + entry
  ValueListenable<double?> progressOf(String localId); // null when not uploading
  void setOnline({required bool online});     // pause / flush
  Future<void> flush();
  void dispose();
}

class RetryPolicy { const RetryPolicy({this.maxAttempts = 5, this.base = const Duration(seconds: 2), this.max = const Duration(minutes: 2)}); }
```

## Behaviour

1. `send`: status `pending` → cache + outbox in one transaction → UI shows it immediately.
2. Run: status `sending`; for each attachment without `remoteUrl`, `uploader.upload(...)` and publish progress on `progressOf(localId)`; write `remoteUrl` back to cache after each upload (so a retry never re-uploads a finished file).
3. `source.send(message)` → confirmed message → `upsertMessages` matched by `localId` (server `id` and `createdAt` replace local ones, status `sent`) → remove outbox entry.
4. `NetworkFailure` / `TimeoutFailure`: keep `pending`, schedule `next_attempt_at` by backoff. Other failures or `maxAttempts` reached: status `failed`, keep entry for manual retry.
5. On `ChatKit.open()` resume all due entries (survives restart). `setOnline(true)` flushes immediately. Entries are processed in `created_at` order per room.
6. Edits/deletes/reactions on a message still pending are merged into the pending send when possible.

## Done when

- [ ] Tests: optimistic row visible before source completes; reconciliation leaves one row with server id; upload progress values emitted; network failure retries with backoff (fake clock); validation failure goes to `failed`; `retry` and `discard`; restart resumes pending entries; completed upload not repeated on retry; ordering preserved per room
- [ ] `ChatKit.setOnline` / `retryPending` wired to the outbox

## Do not

- Delete a failed message silently (valizex did)
- Leave a message in `sending` forever (lightnessword did)
- Rebuild the message list for progress updates (use `ValueListenable`)
