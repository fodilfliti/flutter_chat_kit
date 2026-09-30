# T15 — Profiles and business accounts

## Goal

One account (one login) owns several chat identities, like a personal profile and business pages:

1. **Several profiles.** The person switches between their profiles; only the active profile is connected. Each profile has its own local database and media folder.
2. **Business answered by staff.** Several staff members chat as one business profile. Their messages show on the business side; other staff see who sent each one ("Sara"), customers only see the business.
3. **Customer side.** A normal user chats with a business profile like with any user (name and logo from `ChatUserResolver`).

## Read first

- [../package.md](../package.md), [T05](T05-outbox.md), [T06](T06-controllers.md), [T14](T14-room-filters-mixed-sources.md)

## Depends on

T14.

## Deliverables

```text
lib/src/models/message.dart                 Message.sentBy (staff member who sent it as the author)
lib/src/models/chat_json_keys.dart          ChatJsonKeys.sentBy ('sent_by'), codec
lib/src/models/chat_profile.dart            ChatProfile (id, name, avatarUrl, kind, agentId, unreadCount, metadata)
lib/src/controllers/chat_kit.dart           ChatKit.agentId; outgoing messages get sentBy = agentId
lib/src/controllers/chat_profile_switcher.dart  ChatProfileSwitcher: active profile only, switchTo, setProfiles, setOnline, close, clearAllUserData
lib/src/widgets/profile/chat_profile_scope.dart  ChatProfileScope: provides the active kit, rebuilds the subtree per profile
lib/src/widgets/profile/chat_profile_menu.dart   ChatProfileMenuButton: avatar + menu of profiles with unread badges
message list / grouping / inbox preview     staff-only "sent by" label; runs split per sender; "Sara: ..." preview
doc/adapters/profiles.md                    data model, authorization, per-backend notes
```

## Public API

```dart
final switcher = ChatProfileSwitcher(
  profiles: [
    ChatProfile(id: uid, name: 'Ali'),
    ChatProfile(id: shopId, name: 'Lemsa Shop', kind: ChatProfileKind.business, agentId: uid),
  ],
  createKit: (profile) => ChatKit(
    currentUserId: profile.id,
    agentId: profile.agentId,
    source: MySource(actingAs: profile.id),
  ),
);
await switcher.open();
await switcher.switchTo(shopId);

MaterialApp(builder: (context, child) => ChatProfileScope(switcher: switcher, child: child!));
```

## Done when

- [x] `Message.sentBy` round-trips JSON, the cache and the outbox; outgoing messages carry `ChatKit.agentId`
- [x] Other staff's messages show their name on the business side; the customer side shows none
- [x] Runs of messages split when the sender changes; inbox preview names the staff member
- [x] Only the sender edits their message
- [x] The switcher opens one kit at a time, switches without closing a kit under live controllers, and clears every profile on sign-out
- [x] Example switches between a personal and a business profile; guide compile-checked; analyze and tests green

## As built

- `Message.sentBy` is a base field (every subtype, `copyWith`, equality). The codec reads and writes `sent_by`; the cache keeps it in the message body JSON (no schema change); the outbox stores codec JSON, so pending sends keep it.
- `ChatRoomController` stamps `sentBy = kit.agentId` on every send when the message has none. `sentBy` ids of the profile's own messages are resolved as users (room and inbox); customers never look them up.
- `MessageContext` gains `agentId`, `sender`, `isSentByMe` (mine and `sentBy` is null or me) and `isSentByColleague`. The list shows `sender.name` above the first message of a colleague's run (`ChatConfig.showSentBy`, default on) through `authorNameBuilder`; `MessageRow` pads it on the end side. `GroupPosition` splits runs when `sentBy` changes. Edit requires `isSentByMe`; delete stays on `isMine`.
- `RoomContext` gains `agentId`, `lastMessageSender`, `lastMessageSentByColleague`; `RoomTile.previewOf` prefixes the colleague's name instead of "You".
- `ChatProfileSwitcher` serializes `open`, `switchTo`, `setProfiles`, `close` and `clearAllUserData`. A switch opens the new kit first (a failure keeps the old profile), swaps and notifies, waits for the end of the frame (bounded to 1 s, since no frames come in the background), then closes and disposes the old kit. `setProfiles` clears removed profiles by default and falls back to the first profile. `ChatKit.dispose` now disposes the `AudioPlayerHub` it created.
- `ChatProfileScope` removes its child for one frame on each switch, then builds it under a new key: re-keying alone keeps the state of children with a `GlobalKey` (the `MaterialApp` navigator), which kept the old inbox alive.
- `ChatProfileMenuButton`: active avatar (badge when another profile has unread), menu entries with business label and unread counts, `itemBuilder`, `onSwitchFailed`. New strings `switchProfile`, `businessProfile`.
- Example: one `FakeChatSource` per profile (`me` is now an instance field), a shop seed with staff replies (`sentBy: 'sara'` and you), a "Lemsa Shop" room on the personal side, `ChatProfileScope` in `MaterialApp.builder`, the menu in the inbox app bar.
- Known limit: staff do not see each other typing (typing is sent as the business profile, the current user for all of them).

## Do not

- Keep several profiles connected at once (only the active one)
- Put backend authorization in the kit (the server checks the account may act as the profile)
