import 'dart:async';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/cache/chat_cache.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/chat_json_keys.dart';
import 'package:flutter_chat_kit/src/models/json_utils.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_status.dart';
import 'package:flutter_chat_kit/src/source/chat_source.dart';
import 'package:flutter_chat_kit/src/source/chat_uploader.dart';
import 'package:flutter_chat_kit/src/sync/outbox_entry.dart';
import 'package:flutter_chat_kit/src/sync/retry_policy.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';

/// An edit, delete or reaction the outbox gave up on. Its optimistic
/// change was reverted in the cache. Failed sends are not reported here:
/// they stay in the list with `MessageStatus.failed` until retried or
/// discarded.
@immutable
class OutboxError {
  const OutboxError({required this.entry, required this.failure});

  final OutboxEntry entry;
  final AppFailure failure;

  @override
  String toString() => 'OutboxError(${entry.key}, $failure)';
}

/// The persistent write queue. Every send, edit, delete and reaction is
/// applied to the cache first (so the UI shows it at once), stored as an
/// [OutboxEntry] in the same transaction, then pushed to the source.
///
/// - Entries of one room run in order. An entry waiting for a retry holds
///   back the later entries of its room; a failed send does not.
/// - Connectivity failures (`NetworkFailure`, `TimeoutFailure`) retry with
///   the [retryPolicy] backoff. Other failures, or running out of attempts,
///   mark a send `failed` and revert an edit, delete or reaction.
/// - An `AuthFailure` (expired token) pauses the whole queue without
///   failing anything, and calls [onAuthExpired]; [retryAll] resumes.
/// - Uploaded attachment URLs are written back to the cache one by one, so
///   a retry never uploads a finished file again.
class Outbox {
  Outbox({
    required this.currentUserId,
    required this._source,
    required this._cache,
    this._uploader,
    this.retryPolicy = const RetryPolicy(),
    this._clock = _utcNow,
    this._random,
    this.onUploaded,
    this.onAuthExpired,
    Future<bool> Function(Attachment attachment)? fileAvailable,
  }) : _fileAvailable = fileAvailable ?? _defaultFileAvailable;

  /// Called once when a write fails with an `AuthFailure` (an expired or
  /// revoked token) and the queue pauses. Refresh the session, then call
  /// [retryAll] (`ChatKit.retryPending`) to resume.
  final void Function()? onAuthExpired;

  /// Error code of a send whose local file can no longer be read: on the
  /// web, a `blob:` URL dies with the page, so media queued before a
  /// reload can't upload. Thrown by [retry] as
  /// `ValidationFailure({'attachments': fileUnavailable})`.
  static const fileUnavailable = 'file_unavailable';

  /// Called after each attachment upload with the local file and its new
  /// URL; `ChatKit` copies the file into the media store. Errors are
  /// ignored.
  final Future<void> Function(Attachment local, String remoteUrl)? onUploaded;

  /// Checked before each upload; false fails the send with
  /// [fileUnavailable]. By default only `blob:` paths (web) are checked.
  final Future<bool> Function(Attachment attachment) _fileAvailable;

  final String currentUserId;
  final ChatSource _source;
  final ChatCache _cache;
  final ChatUploader? _uploader;
  final RetryPolicy retryPolicy;
  final DateTime Function() _clock;
  final math.Random? _random;

  static const _codec = MessageCodec();

  final _progress = <String, ValueNotifier<double?>>{};
  final _uploadCancels = <String, void Function()>{};
  final _sending = <String>{};
  final _running = <String>{};

  /// Messages with writes skipped until their send confirms.
  final _awaitingSend = <String>{};
  final _errors = StreamController<OutboxError>.broadcast();
  Future<void> _lock = Future.value();
  Future<void>? _flushing;
  bool _flushAgain = false;
  bool _online = true;
  bool _authPaused = false;
  bool _disposed = false;
  Timer? _timer;

  static String sendKey(String localId) => 'send:$localId';

  static String editKey(String localId) => 'edit:$localId';

  static String deleteKey(String localId) => 'delete:$localId';

  static String reactKey(String localId, String emoji) =>
      'react:$localId:$emoji';

  bool get isOnline => _online;

  /// True after a write failed with an `AuthFailure`: nothing is sent and
  /// queued messages stay "sending" (not failed) until [retryAll],
  /// [retry] or going online again.
  bool get isPausedForAuth => _authPaused;

  /// Edits, deletes and reactions that were rejected and reverted.
  Stream<OutboxError> get errors => _errors.stream;

  /// Upload progress of a message's attachments (0..1), null when nothing
  /// is uploading. Listen to it from the bubble instead of rebuilding the
  /// list.
  ValueListenable<double?> progressOf(String localId) =>
      _progress.putIfAbsent(localId, () => ValueNotifier(null));

  // ----------------------------------------------------------------- writes

  /// Stores [message] as `pending` and queues it. Returns the stored
  /// message. Throws [StateError] when it has attachments to upload and no
  /// `ChatUploader` was given.
  Future<Message> send(Message message) async {
    final pending = message.copyWith(status: MessageStatus.pending);
    if (_uploader == null && _attachmentsOf(pending).any(_needsUpload)) {
      throw StateError('Sending media needs a ChatUploader');
    }
    return await _locked(() async {
      await _cache.stage(
        pending,
        enqueue: OutboxEntry(
          key: sendKey(pending.localId),
          localId: pending.localId,
          roomId: pending.roomId,
          op: OutboxOp.send,
          createdAt: _clock(),
        ),
      );
      _kick();
      return pending;
    });
  }

  /// Replaces the content of the message with [message]'s. An unsent
  /// message is changed in place and sent with the new content.
  Future<void> edit(Message message) {
    return _locked(() async {
      final current = await _cache.messageByAnyId(message.localId);
      if (current == null) return;
      final base = message.copyWith(
        id: current.id,
        createdAt: current.createdAt,
        status: current.status,
      );
      if (_isIdleUnsent(current)) {
        await _cache.upsertMessages([base]);
        return;
      }
      final key = editKey(current.localId);
      final queued = await _cache.outboxEntry(key);
      final edited = base.copyWith(editedAt: _clock());
      await _cache.stage(
        edited,
        enqueue: OutboxEntry(
          key: key,
          localId: current.localId,
          roomId: current.roomId,
          op: OutboxOp.edit,
          createdAt: queued?.createdAt ?? _clock(),
          payload: {
            'message': _codec.encode(edited),
            'previous': queued?.payload['previous'] ?? _codec.encode(current),
          },
        ),
      );
      _kick();
    });
  }

  /// Deletes a message. An unsent one is dropped with its pending writes;
  /// a sent one is marked deleted at once and deleted on the source.
  Future<void> delete(String roomId, String idOrLocalId) {
    return _locked(() async {
      final current = await _cache.messageByAnyId(idOrLocalId);
      if (current == null) return;
      if (_isIdleUnsent(current)) {
        await _drop(current.localId);
        return;
      }
      if (current.isDeleted) return;
      await _cache.stage(
        current.copyWith(deletedAt: _clock()),
        enqueue: OutboxEntry(
          key: deleteKey(current.localId),
          localId: current.localId,
          roomId: roomId,
          op: OutboxOp.delete,
          createdAt: _clock(),
          payload: {'previous': _codec.encode(current)},
        ),
      );
      _kick();
    });
  }

  /// Adds or removes the current user's [emoji] reaction.
  Future<void> react(
    String roomId,
    String idOrLocalId,
    String emoji, {
    required bool add,
  }) {
    return _locked(() async {
      final current = await _cache.messageByAnyId(idOrLocalId);
      if (current == null) return;
      final updated = _toggled(current, emoji, add: add);
      if (updated == null) return;
      final key = reactKey(current.localId, emoji);
      final queued = await _cache.outboxEntry(key);
      if (queued != null &&
          queued.payload['add'] != add &&
          !_running.contains(key)) {
        // The opposite write never left: both cancel out.
        await _cache.stage(updated, removeKeys: [key]);
        return;
      }
      await _cache.stage(
        updated,
        enqueue: OutboxEntry(
          key: key,
          localId: current.localId,
          roomId: roomId,
          op: OutboxOp.react,
          createdAt: _clock(),
          payload: {'emoji': emoji, 'add': add},
        ),
      );
      _kick();
    });
  }

  /// Sends a failed (or waiting) message again now.
  ///
  /// Throws `ValidationFailure({'attachments': 'file_unavailable'})` when
  /// it failed again because its file is gone (see [fileUnavailable]);
  /// offer to delete it.
  Future<void> retry(String localId) async {
    _authPaused = false;
    await _locked(() async {
      final entry = await _cache.outboxEntry(sendKey(localId));
      final message = await _cache.messageByAnyId(localId);
      if (entry == null || message == null) return;
      await _cache.stage(
        message.status == MessageStatus.failed
            ? message.copyWith(status: MessageStatus.pending)
            : message,
        enqueue: _rescheduled(entry, attempts: 0),
      );
    });
    await flush();
    final entry = await _cache.outboxEntry(sendKey(localId));
    final message = await _cache.messageByAnyId(localId);
    if (entry?.lastError == fileUnavailable &&
        message?.status == MessageStatus.failed) {
      throw const ValidationFailure({'attachments': fileUnavailable});
    }
  }

  /// Retries every failed send and every write waiting for its backoff,
  /// and ends a pause after an `AuthFailure` ([isPausedForAuth]).
  Future<void> retryAll() async {
    _authPaused = false;
    await _locked(() async {
      for (final entry in await _cache.outbox()) {
        final message = entry.op == OutboxOp.send
            ? await _cache.messageByAnyId(entry.localId)
            : null;
        if (message != null && message.status == MessageStatus.failed) {
          await _cache.stage(
            message.copyWith(status: MessageStatus.pending),
            enqueue: _rescheduled(entry, attempts: 0),
          );
        } else if (entry.nextAttemptAt != null) {
          await _cache.updateOutbox(
            _rescheduled(entry, attempts: entry.attempts),
          );
        }
      }
    });
    await flush();
  }

  /// Removes an unsent message and its pending writes. Returns false when
  /// the message was already sent, or its send is in flight.
  Future<bool> discard(String localId) {
    return _locked(() async {
      if (_sending.contains(localId)) return false;
      final message = await _cache.messageByAnyId(localId);
      if (message != null && !message.status.isLocal) return false;
      await _drop(localId);
      return true;
    });
  }

  // ------------------------------------------------------------- lifecycle

  /// Offline pauses the queue (running writes finish); online flushes it,
  /// ending an auth pause too.
  void setOnline({required bool online}) {
    if (_online == online) return;
    _online = online;
    if (online) {
      _authPaused = false;
      _kick();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Runs every due entry. Completes when the queue is idle or blocked by
  /// backoff; never throws.
  Future<void> flush() {
    if (!_canRun) return Future.value();
    final running = _flushing;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    return _flushing = _flushLoop();
  }

  /// Stops the queue. Writes in flight may still complete on the source;
  /// their entries run again after the next open.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    for (final cancel in _uploadCancels.values.toList()) {
      cancel();
    }
    await _errors.close();
    for (final notifier in _progress.values) {
      notifier.dispose();
    }
    _progress.clear();
  }

  // ------------------------------------------------------------------- run

  bool get _canRun => _online && !_disposed && !_authPaused;

  void _kick() {
    if (_canRun) unawaited(flush());
  }

  Future<void> _flushLoop() async {
    _timer?.cancel();
    _timer = null;
    // `_flushing` is cleared in the same synchronous step as the last
    // `_flushAgain` check, so a flush request is never lost.
    try {
      do {
        _flushAgain = false;
        final byRoom = <String, List<OutboxEntry>>{};
        for (final entry in await _cache.outbox()) {
          byRoom.putIfAbsent(entry.roomId, () => []).add(entry);
        }
        await Future.wait([for (final list in byRoom.values) _runRoom(list)]);
        if (!_flushAgain && _canRun) await _scheduleNext();
      } while (_flushAgain && _canRun);
    } on Object catch (error, stack) {
      if (!_disposed) _report(error, stack);
    } finally {
      _flushing = null;
    }
  }

  Future<void> _runRoom(List<OutboxEntry> entries) async {
    for (final entry in entries) {
      if (!_canRun) return;
      final at = entry.nextAttemptAt;
      if (at != null && at.isAfter(_clock())) return;
      if (!await _run(entry)) return;
    }
  }

  /// Runs one entry. False holds back the rest of the room.
  Future<bool> _run(OutboxEntry entry) async {
    _running.add(entry.key);
    try {
      switch (entry.op) {
        case OutboxOp.send:
          await _runSend(entry);
        case OutboxOp.edit:
          await _runEdit(entry);
        case OutboxOp.delete:
          await _runDelete(entry);
        case OutboxOp.react:
          await _runReact(entry);
      }
      return true;
    } on AppFailure catch (failure) {
      return await _failed(entry, failure);
    } on Object catch (error, stack) {
      return await _failed(entry, UnknownFailure(cause: error, trace: stack));
    } finally {
      _running.remove(entry.key);
    }
  }

  Future<void> _runSend(OutboxEntry entry) async {
    final localId = entry.localId;
    final stored = await _cache.messageByAnyId(localId);
    if (stored == null || !stored.status.isLocal) {
      // Gone, or its echo already confirmed it.
      await _removeIfUnchanged(entry);
      return;
    }
    if (stored.status == MessageStatus.failed) return;

    final message = await _update(
      localId,
      (m) => m.copyWith(status: MessageStatus.sending),
    );
    if (message == null) return;

    final attachments = _attachmentsOf(message);
    final uploads = [
      for (var i = 0; i < attachments.length; i++)
        if (_needsUpload(attachments[i])) i,
    ];
    if (uploads.isNotEmpty) {
      final uploader = _uploader;
      if (uploader == null) {
        throw const ValidationFailure({'attachments': 'no_uploader'});
      }
      final progress = _progress.putIfAbsent(localId, () => ValueNotifier(null))
        ..value = 0;
      for (var n = 0; n < uploads.length; n++) {
        final index = uploads[n];
        if (!await _fileAvailable(attachments[index])) {
          throw const ValidationFailure({'attachments': fileUnavailable});
        }
        final done = await _upload(
          uploader,
          attachments[index],
          message,
          (fraction) => progress.value = (n + fraction) / uploads.length,
        );
        final written = await _update(
          localId,
          (m) => _withAttachment(
            m,
            index,
            (a) => a.copyWith(
              remoteUrl: done.remoteUrl,
              thumbnailUrl: done.thumbnailUrl,
            ),
          ),
        );
        if (written == null) throw const CancelledFailure();
        final adopt = onUploaded;
        if (adopt != null && attachments[index].localPath != null) {
          try {
            await adopt(attachments[index], done.remoteUrl);
          } on Object {
            // The send goes on; the file downloads when first viewed.
          }
        }
      }
      progress.value = 1;
    }

    final ready = await _locked(() async {
      final m = await _cache.messageByAnyId(localId);
      if (m != null) _sending.add(localId);
      return m;
    });
    if (ready == null) throw const CancelledFailure();
    try {
      final confirmed = await _source.send(ready);
      await _locked(() async {
        final current = await _cache.messageByAnyId(localId);
        final status = confirmed.status.isLocal
            ? MessageStatus.sent
            : confirmed.status;
        if (current != null && !current.status.isLocal) {
          await _cache.removeOutbox(entry.key);
          return;
        }
        // Keep what the user changed meanwhile (queued edits, reactions,
        // deletion); take the server's identity.
        final base = current ?? confirmed.copyWith(localId: localId);
        await _cache.stage(
          base.copyWith(
            id: confirmed.id,
            createdAt: confirmed.createdAt,
            status: status,
          ),
          removeKeys: [entry.key],
        );
      });
    } finally {
      _sending.remove(localId);
    }
    _progress.remove(localId)?.value = null;
    if (_awaitingSend.remove(localId)) _flushAgain = true;
  }

  Future<void> _runEdit(OutboxEntry entry) async {
    final target = await _cache.messageByAnyId(entry.localId);
    final edited = _decode(entry.payload['message']);
    if (target == null || edited == null || target.status.isLocal) {
      // Gone, or never sent: the send carries the new content.
      await _removeIfUnchanged(entry);
      return;
    }
    final result = await _source.edit(
      edited.copyWith(
        id: target.id,
        localId: target.localId,
        createdAt: target.createdAt,
      ),
    );
    await _locked(() async {
      if (await _cache.outboxEntry(entry.key) != entry) return;
      final current = await _cache.messageByAnyId(entry.localId);
      await _cache.stage(
        result.copyWith(
          localId: entry.localId,
          status: current?.status,
          deletedAt: current?.deletedAt,
          reactions: current?.reactions,
        ),
        removeKeys: [entry.key],
      );
    });
  }

  Future<void> _runDelete(OutboxEntry entry) async {
    final target = await _cache.messageByAnyId(entry.localId);
    if (target == null) {
      await _removeIfUnchanged(entry);
      return;
    }
    if (target.status.isLocal) {
      await _locked(() => _drop(entry.localId));
      return;
    }
    await _source.delete(entry.roomId, target.id);
    await _removeIfUnchanged(entry);
  }

  Future<void> _runReact(OutboxEntry entry) async {
    final target = await _cache.messageByAnyId(entry.localId);
    final emoji = entry.payload['emoji'];
    if (target == null || emoji is! String) {
      await _removeIfUnchanged(entry);
      return;
    }
    if (target.status.isLocal) {
      _awaitingSend.add(entry.localId);
      return;
    }
    await _source.react(
      entry.roomId,
      target.id,
      emoji,
      add: entry.payload['add'] == true,
    );
    await _removeIfUnchanged(entry);
  }

  /// Handles a failed run. Returns whether the room may continue.
  Future<bool> _failed(OutboxEntry entry, AppFailure failure) {
    if (failure is CancelledFailure || _disposed) {
      return Future.value(!_disposed);
    }
    return _locked(() async {
      if (await _cache.outboxEntry(entry.key) != entry) return true;
      final attempts = entry.attempts + 1;
      final error = switch (failure) {
        ValidationFailure(:final fields) when fields['attachments'] != null =>
          fields['attachments'],
        _ => failure.runtimeType.toString(),
      };
      final message = entry.op == OutboxOp.send
          ? await _cache.messageByAnyId(entry.localId)
          : null;
      if (entry.op == OutboxOp.send &&
          (message == null || !message.status.isLocal)) {
        await _cache.removeOutbox(entry.key);
        return true;
      }

      if (failure is AuthFailure && _pausesForAuth(failure)) {
        final waiting = _rescheduled(
          entry,
          attempts: entry.attempts,
          error: error,
        );
        if (message != null) {
          await _cache.stage(
            message.copyWith(status: MessageStatus.pending),
            enqueue: waiting,
          );
        } else {
          await _cache.updateOutbox(waiting);
        }
        _progress[entry.localId]?.value = null;
        if (!_authPaused) {
          _authPaused = true;
          _timer?.cancel();
          _timer = null;
          onAuthExpired?.call();
        }
        return false;
      }

      if (retryPolicy.isRetryable(failure) &&
          attempts < retryPolicy.maxAttempts) {
        final next = _rescheduled(
          entry,
          attempts: attempts,
          at: _clock().add(retryPolicy.delay(attempts, random: _random)),
          error: error,
        );
        if (message != null) {
          await _cache.stage(
            message.copyWith(status: MessageStatus.pending),
            enqueue: next,
          );
        } else {
          await _cache.updateOutbox(next);
        }
        return false;
      }

      if (message != null) {
        await _cache.stage(
          message.copyWith(status: MessageStatus.failed),
          enqueue: _rescheduled(entry, attempts: attempts, error: error),
        );
        _progress[entry.localId]?.value = null;
        return true;
      }
      await _revert(entry);
      _errors.add(OutboxError(entry: entry, failure: failure));
      return true;
    });
  }

  /// Undoes the optimistic change of an edit, delete or reaction.
  Future<void> _revert(OutboxEntry entry) async {
    final current = await _cache.messageByAnyId(entry.localId);
    if (current == null) {
      await _cache.removeOutbox(entry.key);
      return;
    }
    final Message? reverted;
    switch (entry.op) {
      case OutboxOp.edit || OutboxOp.delete:
        reverted = _decode(entry.payload['previous'])?.copyWith(
          id: current.id,
          createdAt: current.createdAt,
          status: current.status,
          reactions: current.reactions,
        );
      case OutboxOp.react:
        final emoji = entry.payload['emoji'];
        reverted = emoji is String
            ? _toggled(current, emoji, add: entry.payload['add'] != true)
            : null;
      case OutboxOp.send:
        reverted = null;
    }
    await _cache.stage(reverted ?? current, removeKeys: [entry.key]);
  }

  Future<void> _scheduleNext() async {
    final now = _clock();
    DateTime? earliest;
    for (final entry in await _cache.outbox()) {
      final at = entry.nextAttemptAt;
      if (at == null || !at.isAfter(now)) continue;
      if (earliest == null || at.isBefore(earliest)) earliest = at;
    }
    if (earliest == null || _disposed || !_online) return;
    _timer?.cancel();
    _timer = Timer(earliest.difference(now), _kick);
  }

  Future<UploadDone> _upload(
    ChatUploader uploader,
    Attachment attachment,
    Message message,
    void Function(double fraction) onProgress,
  ) async {
    final completer = Completer<UploadDone>();
    final subscription = uploader
        .upload(attachment, roomId: message.roomId, localId: message.localId)
        .listen(
          (event) {
            switch (event) {
              case UploadRunning(:final fraction):
                onProgress(fraction.clamp(0, 1));
              case UploadDone():
                if (!completer.isCompleted) completer.complete(event);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.completeError(const StorageFailure());
            }
          },
          cancelOnError: true,
        );
    _uploadCancels[message.localId] = () {
      if (!completer.isCompleted) {
        completer.completeError(const CancelledFailure());
      }
    };
    try {
      return await completer.future;
    } finally {
      _uploadCancels.remove(message.localId);
      await subscription.cancel();
    }
  }

  // --------------------------------------------------------------- helpers

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _lock.then((_) {
      if (_disposed) throw const CancelledFailure();
      return action();
    });
    _lock = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Reads the message, applies [change] and stores it, under the lock.
  /// Null when the message is gone.
  Future<Message?> _update(String localId, Message Function(Message) change) {
    return _locked(() async {
      final current = await _cache.messageByAnyId(localId);
      if (current == null) return null;
      final next = change(current);
      await _cache.upsertMessages([next]);
      return next;
    });
  }

  Future<void> _removeIfUnchanged(OutboxEntry entry) {
    return _locked(() async {
      if (await _cache.outboxEntry(entry.key) == entry) {
        await _cache.removeOutbox(entry.key);
      }
    });
  }

  /// Removes a message and all its entries. Call under the lock.
  Future<void> _drop(String localId) async {
    _uploadCancels.remove(localId)?.call();
    for (final entry in await _cache.outbox()) {
      if (entry.localId == localId) await _cache.removeOutbox(entry.key);
    }
    await _cache.deleteMessage(localId);
    _progress.remove(localId)?.value = null;
  }

  bool _isIdleUnsent(Message message) =>
      message.status.isLocal && !_sending.contains(message.localId);

  Message? _toggled(Message message, String emoji, {required bool add}) {
    final users = {...?message.reactions[emoji]};
    final changed = add
        ? users.add(currentUserId)
        : users.remove(currentUserId);
    if (!changed) return null;
    final reactions = {...message.reactions};
    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }
    return message.copyWith(reactions: reactions);
  }

  OutboxEntry _rescheduled(
    OutboxEntry entry, {
    required int attempts,
    DateTime? at,
    String? error,
  }) {
    return OutboxEntry(
      key: entry.key,
      localId: entry.localId,
      roomId: entry.roomId,
      op: entry.op,
      createdAt: entry.createdAt,
      payload: entry.payload,
      attempts: attempts,
      nextAttemptAt: at,
      lastError: error,
    );
  }

  static Message? _decode(Object? json) {
    if (json is! Map) return null;
    return _codec.decode(readMap(json));
  }

  static bool _needsUpload(Attachment a) => !a.isUploaded;

  /// A disabled account won't come back by refreshing a token, and rate
  /// limits are retried with backoff.
  static bool _pausesForAuth(AuthFailure failure) => switch (failure.reason) {
    AuthReason.disabled || AuthReason.rateLimited => false,
    _ => true,
  };

  static Future<bool> _defaultFileAvailable(Attachment attachment) async {
    final path = attachment.localPath;
    if (path == null || !path.startsWith('blob:')) return true;
    try {
      await XFile(path).openRead(0, 1).first;
      return true;
    } on Object {
      return false;
    }
  }

  static List<Attachment> _attachmentsOf(Message message) {
    return switch (message) {
      ImageMessage(:final images) => images,
      VideoMessage(:final video) => [video],
      AudioMessage(:final audio) => [audio],
      FileMessage(:final file) => [file],
      TextMessage() || SystemMessage() || CustomMessage() => const [],
    };
  }

  static Message _withAttachment(
    Message message,
    int index,
    Attachment Function(Attachment) change,
  ) {
    return switch (message) {
      ImageMessage(:final images) => message.copyWith(
        images: [
          for (var i = 0; i < images.length; i++)
            if (i == index) change(images[i]) else images[i],
        ],
      ),
      VideoMessage(:final video) => message.copyWith(video: change(video)),
      AudioMessage(:final audio) => message.copyWith(audio: change(audio)),
      FileMessage(:final file) => message.copyWith(file: change(file)),
      TextMessage() || SystemMessage() || CustomMessage() => message,
    };
  }

  static void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'flutter_chat_kit',
        context: ErrorDescription('while flushing the outbox'),
      ),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
