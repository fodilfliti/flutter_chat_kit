# Customization cookbook

Every screen is built from small, public widgets, and every visible part has
a builder that receives the **default widget**. Wrap the default to add
something, or ignore it to replace the part completely.

- `ChatTheme`: colors, text styles, radii and spacing.
- `ChatBuilders`: the room (messages, bubble, app bar, composer, ...).
- `InboxBuilders`: the inbox rows, empty and error states, swipe actions.
- `ChatStrings`: every piece of text, English by default.
- `ChatFormatters`: times, dates, durations, file sizes.
- `ChatConfig`: behavior (page sizes, grouping, reactions, auto-download).

## Theme

`ChatTheme` is a `ThemeExtension`. Derive it from your color scheme so light
and dark themes stay consistent and animate between each other.

```dart
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    extensions: [
      ChatTheme.fallback(scheme).copyWith(
        bubbleRadius: 12,
        tailRadius: 12,
        outgoingBubbleColor: scheme.primaryContainer,
        outgoingTextStyle: TextStyle(color: scheme.onPrimaryContainer),
        maxBubbleWidthFactor: 0.7,
      ),
    ],
  );
}
```

Without an extension the kit derives one from the ambient `ColorScheme`.
To theme a single screen, pass `theme:` to `ChatRoomView` or `InboxView`.

## Bubble

Replace the bubble shape while keeping the content, reply preview, time and
status the kit builds inside it:

```dart
ChatBuilders(
  bubbleBuilder: (context, m, defaultChild) {
    if (!m.isMine) return defaultChild;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A5AE0), Color(0xFF8E7CFF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: defaultChild,
    );
  },
)
```

`MessageContext` tells you everything about the row: `message`, `author`,
`isMine`, `groupPosition` (first / middle / last of a run), `status`,
`seenBy`, `repliedTo`, `isSelected`, `isHighlighted`, `room`, and
`uploadProgress` (a `ValueListenable`, so listen to it locally).

Other message parts work the same way: `textBuilder`, `imageBuilder`,
`videoBuilder`, `audioBuilder`, `fileBuilder`, `systemBuilder`,
`deletedBuilder`, `avatarBuilder`, `authorNameBuilder`, `statusBuilder`,
`timestampBuilder`, `replyPreviewBuilder`, `reactionsBuilder`, and
`messageBuilder` for the whole row.

## Custom message types

Send any structured payload with `sendCustom`, and render it with a
`customBuilders` entry keyed by the type:

```dart
await room.sendCustom('offer', {
  'title': 'Bike',
  'amount': 120,
  'currency': 'USD',
});

ChatRoomView(
  controller: room,
  builders: ChatBuilders(
    customBuilders: {
      'offer': (context, m) => OfferCard(message: m),
    },
  ),
  // Inbox rows and reply previews use this text.
  strings: ChatStrings(
    customPreview: (type, data) =>
        type == 'offer' ? 'Offer: ${data['title']}' : null,
  ),
)
```

A custom type with no builder falls back to `unsupportedBuilder` (by
default: "Unsupported message"), so older app versions never crash on new
types. The example app has a complete offer card with Accept / Decline.

## App bar

Add actions to the default app bar (presence, typing and member count stay):

```dart
ChatRoomView(
  controller: room,
  appBar: ChatAppBarOptions(
    actions: [
      IconButton(icon: const Icon(Icons.call), onPressed: startCall),
    ],
    onTitleTap: () => openRoomDetails(room.room),
    subtitleBuilder: (context, room, defaultChild) => defaultChild,
  ),
)
```

The same actions can live in `ChatBuilders.appBarActions`, which is handy
when one `ChatBuilders` value is shared by several screens. To replace the
bar, use `ChatBuilders.appBarBuilder` (room bar only) or
`ChatRoomView.appBarBuilder` (also the selection bar; return null to hide
it).

## Composer

Add entries to the attachment sheet:

```dart
ChatRoomView(
  controller: room,
  extraAttachmentOptions: [
    AttachmentOption(
      icon: Icons.location_on_outlined,
      label: 'Location',
      onSelected: () => shareLocation(room),
    ),
  ],
)
```

Replace the default pickers (camera, gallery, video, files) with
`onAttachmentPick`, or wrap the whole input:

```dart
ChatBuilders(
  composerBuilder: (context, defaultChild) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [const QuickReplies(), defaultChild],
  ),
)
```

For a fully custom input, drive a `ComposerController` yourself and pass it
as `composer:`; the view then leaves it alone.

## Long-press actions

```dart
ChatBuilders(
  messageActions: (context, m, defaults) => [
    ...defaults.where((a) => a.id != MessageAction.copyId),
    if (!m.isMine)
      MessageAction(
        id: 'report',
        label: 'Report',
        icon: Icons.flag_outlined,
        isDestructive: true,
        onTap: () => report(m.message),
      ),
  ],
)
```

Default ids: `reply`, `copy`, `edit`, `delete`, `retry`, `select`. Multi
select shows a selection bar with copy, delete, and forward when you pass
`onForward`.

## Inbox

```dart
InboxView(
  controller: inbox,
  onRoomTap: openRoom,
  builders: InboxBuilders(
    trailingBuilder: (context, r, defaultChild) =>
        r.room.metadata['vip'] == true
            ? const Icon(Icons.star, color: Colors.amber)
            : defaultChild,
    swipeActions: (context, r, defaults) => [
      ...defaults,
      RoomAction(
        id: 'archive',
        label: 'Archive',
        icon: Icons.archive_outlined,
        onTap: () => archive(r.room),
      ),
    ],
    emptyBuilder: (context, _) => const StartChatPrompt(),
  ),
)
```

`RoomContext` gives the builder the `room`, the resolved direct `peer`, the
`lastMessageAuthor`, `presence`, and `typingNames`.

## Text and translation

`ChatStrings` holds every visible text, in English by default. Plural and
parameterized texts are functions. Map them from your own localization
(slang, intl, easy_localization, ...):

```dart
ChatStrings chatStrings(Translations t) => ChatStrings(
  typeMessage: t.chat.typeMessage,
  today: t.chat.today,
  yesterday: t.chat.yesterday,
  send: t.chat.send,
  typing: (names) => t.chat.typing(n: names.length, name: names.first),
  members: (count) => t.chat.members(n: count),
  lastSeen: (when) => t.chat.lastSeen(when: when),
  system: (code, args) => switch (code) {
    'member_joined' => t.chat.joined(name: '${args['name']}'),
    _ => code,
  },
);
```

Pass the result to `ChatRoomView(strings: ...)` and `InboxView(strings: ...)`.
System messages carry a `code` and `args` only, so each reader sees them in
their own language.

## Dates and numbers

```dart
ChatFormatters(
  time: (time, locale) => DateFormat.Hm(locale).format(time), // 24h clock
  fileSize: (bytes) => '${(bytes / 1e6).toStringAsFixed(1)} MB',
)
```

`ChatFormatters` uses `intl` with the given locale. Call
`initializeDateFormatting()` (or add `flutter_localizations`) for locales
other than English.

## Behavior

```dart
ChatKit(
  currentUserId: uid,
  source: source,
  config: const ChatConfig(
    pageSize: 50,
    groupingWindow: Duration(minutes: 5),
    showAvatarsInDirect: true,
    quickReactions: ['👍', '🔥', '🎉'],
    autoDownload: {AttachmentKind.image},
    maxAttachmentBytes: 25 * 1024 * 1024,
  ),
);
```

## Building your own screen

`ChatRoomView` and `InboxView` are compositions of public pieces. When the
builders are not enough, compose them yourself:

- `ChatAppBar`, `SelectionAppBar`
- `ChatMessageList` (paging, jump to message, unread divider, typing,
  scroll-to-bottom)
- `ChatComposer`, `VoiceRecordButton`, `ReplyEditBanner`
- `MessageContent`, `MessageBubble`, `MessageRow`
- `RoomTile`, `RoomAvatar`, `InboxSearchBar`, `RoomSwipeActions`

All of them read state from `ChatRoomController` / `InboxController`, which
you can also use with any widgets of your own.
