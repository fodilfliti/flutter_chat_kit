# Supabase adapter

This guide shows one way to implement `ChatSource` and `ChatUploader` on
Supabase (Postgres, Realtime and Storage). The code lives in **your app**:
the kit never depends on `supabase_flutter`.

```yaml
dependencies:
  flutter_chat_pro: ^1.0.0
  lemsa_core_kit: ^1.1.0
  supabase_flutter: ^2.18.0
```

```dart
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
// Realtime has its own Presence class; the kit's is the one used here.
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;
```

## Schema

The column names match `MessageCodec`'s defaults, so rows decode without a
mapping layer.

```sql
create table rooms (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct',
  title text,
  avatar_url text,
  last_message jsonb,
  updated_at timestamptz not null default now()
);

create table room_members (
  room_id uuid references rooms on delete cascade,
  user_id uuid references auth.users on delete cascade,
  role text not null default 'member',
  last_read_at timestamptz,
  last_delivered_at timestamptz,
  unread_count int not null default 0,
  pinned boolean not null default false,
  muted boolean not null default false,
  labels text[] not null default '{}',  -- per user, for RoomFilter
  primary key (room_id, user_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  local_id text not null unique,
  room_id uuid not null references rooms on delete cascade,
  author_id uuid not null references auth.users,
  type text not null default 'text',
  text text,
  caption text,
  attachments jsonb,
  attachment jsonb,
  duration_ms int,
  waveform jsonb,
  code text,
  args jsonb,
  custom_type text,
  data jsonb,
  reply_to_id text,
  reactions jsonb not null default '{}',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create index messages_page on messages (room_id, created_at desc, id desc);
create index rooms_page on rooms (updated_at desc, id desc);
```

### Row level security

```sql
alter table rooms enable row level security;
alter table room_members enable row level security;
alter table messages enable row level security;

create function is_member(r uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from room_members where room_id = r and user_id = auth.uid()
  );
$$;

create policy "members read rooms" on rooms for select using (is_member(id));
create policy "members read members" on room_members
  for select using (is_member(room_id));
create policy "own membership" on room_members
  for update using (user_id = auth.uid());
create policy "members read messages" on messages
  for select using (is_member(room_id));
create policy "authors edit" on messages
  for update using (author_id = auth.uid());
```

### Idempotent send

`send` must not duplicate on retry. The RPC inserts on `local_id` and
returns the existing row when it is already there. It also bumps the room
and the other members' unread counts in the same transaction.

```sql
create function send_message(m jsonb) returns messages
language plpgsql security invoker as $$
declare
  row messages;
begin
  if not is_member((m->>'room_id')::uuid) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  insert into messages (local_id, room_id, author_id, type, text, caption,
    attachments, attachment, duration_ms, waveform, custom_type, data,
    reply_to_id, metadata)
  values (m->>'local_id', (m->>'room_id')::uuid, auth.uid(),
    coalesce(m->>'type', 'text'), m->>'text', m->>'caption',
    m->'attachments', m->'attachment', (m->>'duration_ms')::int,
    m->'waveform', m->>'custom_type', m->'data', m->>'reply_to_id',
    coalesce(m->'metadata', '{}'))
  on conflict (local_id) do nothing
  returning * into row;

  if row.id is null then
    select * into row from messages where local_id = m->>'local_id';
    return row;
  end if;

  update rooms set last_message = to_jsonb(row), updated_at = row.created_at
    where id = row.room_id;
  update room_members set unread_count = unread_count + 1
    where room_id = row.room_id and user_id <> auth.uid();
  return row;
end;
$$;
```

Add `messages`, `rooms` and `room_members` to the `supabase_realtime`
publication so Postgres changes are broadcast.

## Errors

```dart
AppFailure _failure(Object error) => switch (error) {
  AppFailure f => f,
  SocketException() || RealtimeSubscribeException() =>
    NetworkFailure(cause: error),
  TimeoutException() => TimeoutFailure(cause: error),
  AuthException() => AuthFailure(AuthReason.expired, cause: error),
  PostgrestException(code: '42501') => PermissionFailure('chat', cause: error),
  PostgrestException(code: 'PGRST116') => NotFoundFailure('chat', cause: error),
  PostgrestException(code: '23505') => ConflictFailure(cause: error),
  PostgrestException(:final code) => ServerFailure(code: code, cause: error),
  _ => UnknownFailure(cause: error),
};

Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on Object catch (e) {
    throw _failure(e);
  }
}
```

## The source

```dart
class SupabaseChatSource implements ChatSource {
  SupabaseChatSource(this._db);

  final SupabaseClient _db;
  final _channels = <String, RealtimeChannel>{};
  static const _codec = MessageCodec();

  String get _uid => _db.auth.currentUser!.id;

  ChatRoom _room(Map<String, dynamic> row) {
    final mine = row['room_members'] as List? ?? const [];
    final me = mine.cast<Map<String, dynamic>>().firstWhere(
      (m) => m['user_id'] == _uid,
      orElse: () => const {},
    );
    return ChatRoom.fromJson({
      ...row,
      'members': mine,
      'unread_count': me['unread_count'],
      'pinned': me['pinned'],
      'muted': me['muted'],
      'labels': me['labels'],
    });
  }

  @override
  Future<ChatPage<ChatRoom>> fetchRooms({
    RoomCursor? after,
    int limit = 20,
    String? search,
    RoomFilter filter = RoomFilter.all,
  }) => _guard(() async {
    // `me` is the current user's membership, inner-joined so filters on it
    // select rooms; `room_members` still embeds every member.
    var q = _db
        .from('rooms')
        .select('*, room_members(*), me:room_members!inner(labels, unread_count)')
        .eq('me.user_id', _uid);
    if (search != null && search.isNotEmpty) q = q.ilike('title', '%$search%');
    if (filter.types case final types?) {
      q = q.inFilter('type', [for (final t in types) t.name]);
    }
    if (filter.labels case final labels?) {
      q = q.overlaps('me.labels', labels.toList());
    }
    if (filter.excludeLabels case final excluded?) {
      q = q.not('me.labels', 'ov', '{${excluded.join(',')}}');
    }
    if (filter.unreadOnly) q = q.gt('me.unread_count', 0);
    if (after != null) {
      final t = after.updatedAt.toIso8601String();
      q = q.or('updated_at.lt.$t,and(updated_at.eq.$t,id.lt.${after.id})');
    }
    final rows = await q
        .order('updated_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit + 1);
    return ChatPage(
      items: [for (final r in rows.take(limit)) _room(r)],
      hasMore: rows.length > limit,
    );
  });

  @override
  Future<ChatPage<Message>> fetchMessages(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) => _guard(() async {
    var q = _db.from('messages').select().eq('room_id', roomId);
    if (before != null) {
      final t = before.createdAt.toIso8601String();
      q = q.or('created_at.lt.$t,and(created_at.eq.$t,id.lt.${before.id})');
    }
    if (after != null) {
      final t = after.createdAt.toIso8601String();
      q = q.or('created_at.gt.$t,and(created_at.eq.$t,id.gt.${after.id})');
    }
    final newer = after != null;
    final rows = await q
        .order('created_at', ascending: newer)
        .order('id', ascending: newer)
        .limit(limit + 1);
    final items = [for (final r in rows.take(limit)) _codec.decode(r)];
    return ChatPage(
      items: newer ? items.reversed.toList() : items,
      hasMore: rows.length > limit,
    );
  });

  @override
  Future<ChatPage<Message>?> fetchAround(
    String roomId,
    String messageId, {
    int limit = 30,
  }) => _guard(() async {
    final row = await _db
        .from('messages')
        .select()
        .or('id.eq.$messageId,local_id.eq.$messageId')
        .single();
    final target = _codec.decode(row);
    final half = limit ~/ 2;
    final newer = await fetchMessages(roomId, after: target.cursor, limit: half);
    final older = await fetchMessages(roomId, before: target.cursor, limit: half);
    return ChatPage(
      items: [...newer.items, target, ...older.items],
      hasMore: older.hasMore,
    );
  });

  @override
  Future<Message> send(Message pending) => _guard(() async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'send_message',
      params: {'m': pending.toJson()},
    );
    return _codec.decode(row);
  });

  @override
  Future<Message> edit(Message message) => _guard(() async {
    final row = await _db
        .from('messages')
        .update({
          'text': ?switch (message) {
            TextMessage(:final text) => text,
            _ => null,
          },
          'caption': ?switch (message) {
            ImageMessage(:final caption) => caption,
            _ => null,
          },
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('local_id', message.localId)
        .select()
        .single();
    return _codec.decode(row);
  });

  @override
  Future<void> delete(String roomId, String messageId) => _guard(
    () => _db
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('room_id', roomId)
        .or('id.eq.$messageId,local_id.eq.$messageId'),
  );

  @override
  Future<void> markRead(String roomId, MessageCursor upTo) => _guard(
    () => _db
        .from('room_members')
        .update({
          'last_read_at': upTo.createdAt.toIso8601String(),
          'unread_count': 0,
        })
        .eq('room_id', roomId)
        .eq('user_id', _uid),
  );

  @override
  Future<void> setPinned(String roomId, {required bool pinned}) => _guard(
    () => _db
        .from('room_members')
        .update({'pinned': pinned})
        .eq('room_id', roomId)
        .eq('user_id', _uid),
  );

  @override
  Future<void> setMuted(String roomId, {required bool muted}) => _guard(
    () => _db
        .from('room_members')
        .update({'muted': muted})
        .eq('room_id', roomId)
        .eq('user_id', _uid),
  );

  @override
  Future<void> react(
    String roomId,
    String messageId,
    String emoji, {
    required bool add,
  }) => _guard(
    // A small `toggle_reaction(message_id, emoji, add)` RPC keeps the
    // jsonb update atomic.
    () => _db.rpc<void>('toggle_reaction', params: {
      'message_id': messageId,
      'emoji': emoji,
      'add': add,
    }),
  );

  @override
  Future<void> setTyping(String roomId, {required bool typing}) async {
    await _channels[roomId]?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _uid, 'typing': typing},
    );
  }

  @override
  Stream<ChatEvent> events({String? roomId}) =>
      roomId == null ? _inboxEvents() : _roomEvents(roomId);
}
```

## Realtime to `ChatEvent`

One channel per open room carries Postgres changes for its messages,
broadcast events for typing, and member updates for read receipts.

```dart
extension on SupabaseChatSource {
  Stream<ChatEvent> _roomEvents(String roomId) {
    late final StreamController<ChatEvent> out;
    out = StreamController<ChatEvent>(
      onListen: () {
        final eq = PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        );
        _channels[roomId] = _db
            .channel('room:$roomId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: eq,
              callback: (p) {
                if (p.newRecord.isEmpty) return;
                final m = SupabaseChatSource._codec.decode(p.newRecord);
                out.add(
                  MessageChanged(
                    roomId: roomId,
                    change: p.eventType == PostgresChangeEvent.insert
                        ? Created(m)
                        : Updated(m),
                  ),
                );
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'room_members',
              filter: eq,
              callback: (p) {
                final r = p.newRecord;
                out.add(
                  ReceiptChanged(
                    roomId: roomId,
                    userId: r['user_id'] as String,
                    readAt: DateTime.tryParse('${r['last_read_at']}'),
                    deliveredAt: DateTime.tryParse('${r['last_delivered_at']}'),
                  ),
                );
              },
            )
            .onBroadcast(
              event: 'typing',
              callback: (p) {
                if (p['user_id'] == _uid) return;
                out.add(
                  TypingChanged(
                    roomId: roomId,
                    userId: p['user_id'] as String,
                    typing: p['typing'] == true,
                  ),
                );
              },
            )
            .subscribe((status, error) {
              if (error != null) out.addError(NetworkFailure(cause: error));
            });
      },
      onCancel: () async {
        final channel = _channels.remove(roomId);
        if (channel != null) await _db.removeChannel(channel);
      },
    );
    return out.stream;
  }

  // Presence through a shared `online` channel. Add a `room_members`
  // listener (filter `user_id=eq.$uid`) on the same channel that re-reads
  // the changed room with `select('*, room_members(*)')` and emits
  // `RoomChanged(Updated(room))`.
  Stream<ChatEvent> _inboxEvents() {
    late final StreamController<ChatEvent> out;
    late final RealtimeChannel presence;
    out = StreamController<ChatEvent>(
      onListen: () {
        presence = _db.channel('online')
          ..onPresenceSync((_) {
            for (final state in presence.presenceState()) {
              for (final p in state.presences) {
                out.add(PresenceChanged(Presence(
                  userId: p.payload['user_id'] as String,
                  isOnline: true,
                )));
              }
            }
          })
          ..onPresenceLeave((payload) {
            for (final p in payload.leftPresences) {
              out.add(PresenceChanged(Presence(
                userId: p.payload['user_id'] as String,
                isOnline: false,
                lastSeenAt: DateTime.now().toUtc(),
              )));
            }
          })
          ..subscribe((status, _) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              await presence.track({'user_id': _uid});
            }
          });
      },
      onCancel: () => _db.removeChannel(presence),
    );
    return out.stream;
  }
}
```

## Names and avatars

Keep names in a `profiles` table and point `messages.author_id` (and
`room_members.user_id`) at it, so one query returns messages **with** their
authors:

```sql
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  avatar_url text
);
alter table profiles enable row level security;
create policy "profiles are readable" on profiles for select using (true);

-- instead of `references auth.users` above:
--   messages.author_id    uuid not null references profiles
--   room_members.user_id  uuid references profiles on delete cascade
```

Embed the profile and hand it to the kit with `ChatPage.users`. In
`fetchMessages`:

```dart
var q = _db
    .from('messages')
    .select('*, author:profiles!author_id(id, name, avatar_url)')
    .eq('room_id', roomId);
// ... cursors and order as above ...
return ChatPage(
  items: newer ? items.reversed.toList() : items,
  hasMore: rows.length > limit,
  users: [
    for (final r in rows)
      if (r['author'] case final Map<String, dynamic> author)
        ChatUser.fromJson(author),
  ],
);
```

and in `fetchRooms`, with `select('*, room_members(*, profile:profiles(id, name, avatar_url)), me:room_members!inner(labels, unread_count)')`:

```dart
users: [
  for (final r in rows)
    for (final m in r['room_members'] as List)
      if (m['profile'] case final Map<String, dynamic> p) ChatUser.fromJson(p),
],
```

The kit saves these users, shows them, and replaces them whenever a page
brings a different name or avatar. With every page carrying its people you
can drop `SupabaseUserResolver`.

To show a rename at once, add the `profiles` table to the
`supabase_realtime` publication and, on the inbox channel, turn its updates
into `UsersChanged`:

```dart
.onPostgresChanges(
  event: PostgresChangeEvent.update,
  schema: 'public',
  table: 'profiles',
  callback: (p) => out.add(UsersChanged([ChatUser.fromJson(p.newRecord)])),
)
```

After the signed-in user edits their own profile, you can also call
`kit.updateUsers([ChatUser(id: uid, name: name, avatarUrl: url)])`.

## Uploads with Supabase Storage

```dart
class SupabaseUploader implements ChatUploader {
  SupabaseUploader(this._db);

  final SupabaseClient _db;

  @override
  Stream<UploadProgress> upload(
    Attachment attachment, {
    required String roomId,
    required String localId,
  }) async* {
    final path = '$roomId/$localId/${attachment.name ?? 'file'}';
    final bucket = _db.storage.from('chat');
    try {
      // Supabase uploads report no progress; emit a start value so the
      // bubble shows a spinner. Use TUS (resumable) for large files.
      yield const UploadRunning(0);
      // readAsBytes works on web too, where localPath is a blob: URL.
      await bucket.uploadBinary(
        path,
        await attachment.readAsBytes(),
        fileOptions: FileOptions(contentType: attachment.mimeType),
      );
      final url = await bucket.createSignedUrl(path, 60 * 60 * 24 * 365);
      yield UploadDone(remoteUrl: url);
    } on Object catch (e) {
      throw _failure(e);
    }
  }
}
```

`attachment.readAsBytes()` loads the file in memory, which is fine for
photos and voice notes. For long videos, use Supabase's resumable (TUS)
upload with `attachment.openRead()` so the file is streamed.

## Wiring

```dart
final supabase = Supabase.instance.client;
final kit = ChatKit(
  currentUserId: supabase.auth.currentUser!.id,
  source: SupabaseChatSource(supabase),
  uploader: SupabaseUploader(supabase),
  // Optional when pages carry their profiles (see "Names and avatars").
  users: SupabaseUserResolver(supabase), // select id, name, avatar_url in ids
);
await kit.open();
```
