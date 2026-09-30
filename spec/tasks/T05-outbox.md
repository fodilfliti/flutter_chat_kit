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

### As built

- `Outbox({currentUserId, source, cache, uploader, retryPolicy, clock, random})`. The policy field is named `retryPolicy` because `retry(localId)` is a method. `ChatKit(retryPolicy:)` passes it through; `ChatKit.outbox` is available while the kit is open.
- `send` throws `StateError` at once when the message has files to upload and there is no `ChatUploader`. `discard` returns `bool`: false when the message was already sent or its send is in flight. `retryAll()` backs `ChatKit.retryPending`. `flush()` never throws; `dispose()` is async.
- Every optimistic change and its entry are written together through the new `ChatCache.stage(message, enqueue:, removeKeys:)`. `ChatCache.outboxEntry(key)` was added too. Outbox order is `createdAt`, then insertion order (rowid).
- Keys: `send:<localId>`, `edit:<localId>`, `delete:<localId>`, `react:<localId>:<emoji>`. A queued edit keeps its first `previous` snapshot. An add and a remove of the same reaction that never left cancel out.
- Merging (behaviour 6): editing an unsent message that is not in flight changes it in place, and deleting one drops it with all its entries. A reaction, or an edit or delete queued while the send is in flight, waits for the send and then targets the server id.
- On confirm, the local row keeps what the user changed meanwhile (content, reactions, deletion) and takes the server `id`, `createdAt` and status. When the realtime echo landed first, the echo wins and the entry is just removed.
- Rejected edits, deletes and reactions are reverted in the cache and reported on `Outbox.errors` (`OutboxError{entry, failure}`). Failed sends are not reported there: they stay with `MessageStatus.failed`.
- A room's entries run in order. An entry waiting for its backoff holds back its room; a failed send does not. Rooms run concurrently. A timer flushes again at the earliest `nextAttemptAt`.
- Progress runs 0 → per-file fractions → 1 → null. Remote URLs are written back after each file, keeping `localPath` so the bubble doesn't flicker.
- A finished run only removes or updates its entry if the stored entry is unchanged, so a write queued during the run is never lost.

## Done when

- [x] Tests: optimistic row visible before source completes; reconciliation leaves one row with server id; upload progress values emitted; network failure retries with backoff (fake clock); validation failure goes to `failed`; `retry` and `discard`; restart resumes pending entries; completed upload not repeated on retry; ordering preserved per room
- [x] `ChatKit.setOnline` / `retryPending` wired to the outbox

## Do not

- Delete a failed message silently (valizex did)
- Leave a message in `sending` forever (lightnessword did)
- Rebuild the message list for progress updates (use `ValueListenable`)
