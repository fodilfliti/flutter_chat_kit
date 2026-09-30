# Profiles and business accounts

One login (an **account**) can own several **profiles**: the person's own
profile, and business pages they own or work for. This guide covers:

1. [The model](#the-model): who is who in rooms and messages.
2. [In the app](#in-the-app): `ChatProfileSwitcher`, `ChatProfileScope`,
   `ChatProfileMenuButton`.
3. [What each side sees](#what-each-side-sees): staff and customers.
4. [The backend](#the-backend): tables, authorization, and notes for
   Supabase, Firestore and REST.

## The model

| Concept | In the kit | Example |
| --- | --- | --- |
| Account | `ChatKit.agentId` / `Message.sentBy` | `ali` (signs in with email) |
| Profile | `ChatKit.currentUserId` / `Message.authorId` | `ali`, `lemsa-shop`, `ali-studio` |
| Room member | `RoomMember.userId` (a profile id) | `lemsa-shop`, `omar` |

- **Rooms belong to profiles.** A customer chats with `lemsa-shop`, not with
  Ali. Room members, read pointers, unread counts and messages use profile
  ids.
- **A business can be answered by several staff members.** Each message the
  shop sends has `authorId = lemsa-shop` and `sentBy = <staff account>`. The
  customer sees the shop; colleagues see who answered.
- **A personal profile** usually has the same id as the account, and
  `sentBy` stays null.
- **Only the active profile is connected.** Each profile has its own local
  database and media folder; switching opens the new one and closes the old
  one. Unread counts of the other profiles come from your backend.

## In the app

```dart
final switcher = ChatProfileSwitcher(
  profiles: [
    ChatProfile(id: uid, name: 'Ali'),
    ChatProfile(
      id: 'lemsa-shop',
      name: 'Lemsa Shop',
      kind: ChatProfileKind.business,
      agentId: uid, // stamped on sent messages as Message.sentBy
    ),
  ],
  createKit: (profile) => ChatKit(
    currentUserId: profile.id,
    agentId: profile.agentId,
    source: MyChatSource(actingAs: profile.id),
    uploader: MyUploader(),
    users: MyUserResolver(),
  ),
);
await switcher.open();

MaterialApp(
  builder: (context, child) => ChatProfileScope(
    switcher: switcher,
    placeholder: const Center(child: CircularProgressIndicator()),
    child: child!,
  ),
  home: const InboxPage(),
);
```

- `createKit` must return a **new** kit every time; the switcher opens,
  closes and disposes it.
- `ChatProfileScope` provides the active kit as `ChatKitScope`
  (`context.chatKit`) and the switcher (`context.chatProfiles`). On every
  switch it removes its child for one frame and builds it again, so open
  chat screens and their controllers are disposed before the old kit
  closes, and the app navigator starts again at `home`.
- `ChatProfileMenuButton()` in the inbox app bar shows the active profile's
  avatar and a menu of every profile, with a business badge and unread
  counts. `itemBuilder` customizes the entries.
- `switcher.switchTo(profileId)` switches from code, for example when a
  push notification for another profile is tapped:

```dart
await switcher.switchTo(notification.profileId);
navigatorKey.currentState!.push(RoomRoute(notification.roomId));
```

- `switcher.setProfiles(list)` replaces the list after the account joins or
  leaves a business, or with fresh unread counts. Removed profiles have
  their cached data deleted (`clearRemoved: false` keeps it). If the active
  profile is removed, the first profile becomes active.
- `switcher.setOnline(online: ...)` feeds connectivity to the active kit
  and to the next ones.
- On sign-out: `await switcher.clearAllUserData()` (closes the kit and
  deletes every profile's cached data), then `switcher.dispose()`.

### Unread counts of other profiles

Only the active profile is connected, so the kit cannot count messages of
the others. Return them with the profile list (`ChatProfile.unreadCount`),
for example from `GET /me/profiles`, and refresh with `setProfiles` when a
push notification arrives or the app resumes.

## What each side sees

**Staff on a business profile** (`agentId` set):

- Messages of the business are on the "mine" side, whoever wrote them.
- A colleague's messages show their name above the bubble
  (`ChatConfig.showSentBy`, on by default). Your own do not.
- The inbox preview says "Sara: ..." instead of "You: ..." when a colleague
  sent the last message.
- Only messages you wrote can be edited; any message of the business can be
  deleted. Restrict delete further in your backend if needed.
- Staff do not see each other typing: typing is sent as the business
  profile, which is the current user for everyone on it.

**A customer** sees the business as one user: its name and avatar from your
`ChatUserResolver`. The kit never shows `sentBy` for messages of other
people.

Customize with the builders: `MessageContext.sender` (the resolved staff
member), `isSentByColleague` and `isSentByMe`; `RoomContext.lastMessageSender`
and `lastMessageSentByColleague`. For example, a verified badge for
businesses on the customer side:

```dart
ChatBuilders(
  authorNameBuilder: (context, message, fallback) {
    if (message.isSentByColleague) {
      return Text('${message.sender?.name} for the shop');
    }
    return fallback;
  },
)

InboxBuilders(
  titleBuilder: (context, room, fallback) {
    final isBusiness = room.peer?.metadata['business'] == true;
    return isBusiness
        ? Row(children: [Flexible(child: fallback), const Icon(Icons.verified, size: 16)])
        : fallback;
  },
)
```

## The backend

### Data model

```text
accounts           id, email, ...
profiles           id, kind ('personal' | 'business'), name, avatar_url
profile_members    profile_id, account_id, role ('owner' | 'staff')
room_members       room_id, user_id -> profiles.id, unread_count, ...
messages           ..., author_id -> profiles.id, sent_by -> accounts.id
```

The personal profile can reuse the account id, so the guides for
[Firestore](firestore.md), [Supabase](supabase.md) and
[REST](rest_websocket.md) work unchanged for it.

### Authorization

Every request acts as one profile. The server checks that the signed-in
account may act as it, and sets `sent_by` itself:

- **Reads** (rooms, messages, members): allowed when the account can act as
  a member profile of the room.
- **Send**: `author_id` must be a profile the account can act as and a
  member of the room; `sent_by` is the account id (null when the profile is
  the account itself). Never trust `sent_by` from the client.
- **Edit**: only the account in `sent_by` (or the author, for personal
  profiles).
- **Mark read, pin, mute, labels**: on the acting profile's membership row.

`sent_by` reaches customers too unless you strip it. The kit does not show
it to them, so stripping is optional hardening: do it in the API (REST) or
a view (Supabase) when staff identities must stay private.

### Supabase

```sql
create table profiles (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'personal',
  name text not null,
  avatar_url text
);

create table profile_members (
  profile_id uuid references profiles on delete cascade,
  account_id uuid references auth.users on delete cascade,
  role text not null default 'staff',
  primary key (profile_id, account_id)
);

alter table messages add column sent_by uuid references auth.users;

create function can_act_as(p uuid) returns boolean
language sql security definer stable as $$
  select p = auth.uid() or exists (
    select 1 from profile_members where profile_id = p and account_id = auth.uid()
  );
$$;

-- Members of a room are profiles now.
create or replace function is_member(r uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from room_members where room_id = r and can_act_as(user_id)
  );
$$;
```

Point `room_members.user_id` and `messages.author_id` at `profiles(id)`
instead of `auth.users`, replace `auth.uid()` with `can_act_as(user_id)` in
the membership policies, and in `send_message` take the author from the
payload:

```sql
  if not can_act_as((m->>'author_id')::uuid)
     or not exists (select 1 from room_members
       where room_id = (m->>'room_id')::uuid
         and user_id = (m->>'author_id')::uuid) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  insert into messages (local_id, room_id, author_id, sent_by, ...)
  values (m->>'local_id', (m->>'room_id')::uuid, (m->>'author_id')::uuid,
    nullif(auth.uid(), (m->>'author_id')::uuid), ...)
```

In the adapter, use the acting profile wherever the guide uses the current
user:

```dart
class SupabaseChatSource implements ChatSource {
  SupabaseChatSource(this._db, {String? actingAs}) : _actingAs = actingAs;

  final SupabaseClient _db;
  final String? _actingAs;

  String get _uid => _actingAs ?? _db.auth.currentUser!.id;
  // ... the rest of the guide unchanged
}
```

### Firestore

Keep `member_ids` holding profile ids and give the adapter the acting
profile (`FirestoreChatSource(db, profileId)`: the guide's `_uid` becomes
the profile). Write messages through a callable Cloud Function (or check in
rules) so `sent_by` is set from `request.auth.uid`:

```js
function canActAs(p) {
  return p == request.auth.uid ||
    exists(/databases/$(database)/documents/profiles/$(p)/staff/$(request.auth.uid));
}

match /rooms/{roomId}/messages/{messageId} {
  allow create: if canActAs(request.resource.data.author_id)
    && request.resource.data.author_id in get(/databases/$(database)/documents/rooms/$(roomId)).data.member_ids
    && (request.resource.data.author_id == request.auth.uid
        ? !('sent_by' in request.resource.data)
        : request.resource.data.sent_by == request.auth.uid);
}
```

Rules cannot loop over "every profile of this account" in a list query. Two
layouts work:

- **Per-profile inbox**: mirror each room into
  `profiles/{profileId}/rooms/{roomId}` (unread, pinned, labels), written
  by a Cloud Function on each message; the rule is simply
  `allow read: if canActAs(profileId)`.
- **Server API** for business profiles (REST below) with Firestore only for
  realtime (see [mixing backends](mixing.md)).

Firestore cannot hide a field from some readers, so `sent_by` is visible to
customers who read the raw documents.

### REST

Send the acting profile with every request, for example
`X-Acting-As: lemsa-shop`, and check it in one middleware:

```dart
class RestChatSource implements ChatSource {
  RestChatSource({
    required this.baseUrl,
    required this.socketUrl,
    required this.token,
    this.actingAs,
    http.Client? client,
  }) : _http = client ?? http.Client();

  /// The profile every request acts as; null for the account itself.
  final String? actingAs;

  // In _call, next to the authorization header:
  //   if (actingAs case final profile?) req.headers['x-acting-as'] = profile;
}
```

```text
middleware: profile = header('x-acting-as') ?? account.id
            403 unless profile == account.id
                    or profile_members(profile, account.id) exists
POST /rooms/:id/messages   author_id = profile, sent_by = account.id (if different)
GET  /me/profiles          [{ id, name, kind, avatar_url, unread_count }]
```

`GET /me/profiles` returns JSON that `ChatProfile.fromJson` reads directly.
Open the realtime connection (WebSocket, SSE) with the same header or query
parameter, so events are for the acting profile only.
