# Customization cookbook

Every screen is built from small, public widgets, and every visible part has
a builder that receives the **default widget**. Wrap the default to add
something, or ignore it to replace the part completely.

- `ChatTheme`: one style per part (bubbles, list, composer, room tiles, ...)
  with every color, text style, size, radius, border and shadow, plus a
  global scale.
- `ChatBuilders`: the room (messages, bubble, app bar, composer, ...).
- `InboxBuilders`: the inbox rows, empty and error states, swipe actions.
- `ChatStrings`: every piece of text, English by default.
- `ChatFormatters`: times, dates, durations, file sizes.
- `ChatConfig`: behavior (page sizes, grouping, reactions, auto-download).

## Theme

`ChatTheme` is a `ThemeExtension` made of one style per part. Every value
the default widgets draw comes from it:

| Group | Part |
| --- | --- |
| `outgoingBubble`, `incomingBubble` | `ChatBubbleStyle`: color or gradient, text and meta styles, radius, tail radius, padding, border, shadows |
| `messageList` | spacing, bubble width, avatars, author names, highlight, background (wallpaper) |
| `status` | tick colors and size |
| `dateSeparator`, `systemMessage`, `unreadDivider` | `ChatChipStyle` |
| `reactions`, `replyPreview`, `media` | reaction chips, quoted messages, image and video bubbles |
| `composer`, `appBar`, `avatar`, `badge` | input bar (also the inbox search), room header, avatars, unread counters |
| `roomTile` | inbox rows: text styles, background, any `ShapeBorder`, elevation, divider, margin |

Derive it from your color scheme so light and dark themes stay consistent
and animate between each other, then change only what you need:

```dart
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  );
  final base = ChatTheme.fallback(scheme);
  return ThemeData(
    colorScheme: scheme,
    extensions: [
      base.copyWith(
        outgoingBubble: base.outgoingBubble.copyWith(
          color: scheme.primaryContainer,
          textStyle: base.outgoingBubble.textStyle.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
        messageList: base.messageList.copyWith(maxBubbleWidthFactor: 0.7),
      ),
    ],
  );
}
```

Without an extension the kit derives one from the ambient `ColorScheme` and
`TextTheme`. To theme a single screen, pass `theme:` to `ChatRoomView` or
`InboxView`.

### Common changes

Message text of 14 in grey, for both sides:

```dart
ChatTheme.fallback(scheme).withMessageText(
  const TextStyle(fontSize: 14, color: Colors.grey),
)
```

Both bubbles at once, and a font for every text:

```dart
ChatTheme.fallback(scheme)
    .mapBubbles(
      (b) => b.copyWith(
        radius: 8,
        border: BorderSide(color: scheme.outlineVariant),
        shadows: const [BoxShadow(color: Color(0x22000000), blurRadius: 3)],
      ),
    )
    .mapText((s) => s.copyWith(fontFamily: 'Cairo'))
```

A gradient for your own bubbles and a wallpaper behind the messages:

```dart
final base = ChatTheme.fallback(scheme);
base.copyWith(
  outgoingBubble: base.outgoingBubble.copyWith(
    gradient: const LinearGradient(
      colors: [Color(0xFF2AABEE), Color(0xFF6A5AE0)],
    ),
  ),
  messageList: base.messageList.copyWith(
    background: const BoxDecoration(color: Color(0xFFEFEAE2)),
  ),
)
```

### Inbox rows

Start from a preset and adjust it; `shape` takes any `ShapeBorder`:

```dart
final base = ChatTheme.fallback(scheme);

// Edge to edge (default).
base.copyWith(roomTile: ChatRoomTileStyle.plain(scheme));

// A line under each row only, starting at the title (or `indent: 0`).
base.copyWith(roomTile: ChatRoomTileStyle.divided(scheme));

// Separate cards.
base.copyWith(
  roomTile: ChatRoomTileStyle.card(
    scheme,
    radius: 20,
    elevation: 1,
    side: BorderSide(color: scheme.outlineVariant),
  ),
);

// Anything else.
base.copyWith(
  roomTile: ChatRoomTileStyle.card(scheme).copyWith(
    shape: const BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    avatarSize: 44,
    titleStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
  ),
);
```

Square avatars: `base.copyWith(avatar: base.avatar.copyWith(radius: 10))`.

### Scale

`scaled` multiplies every size, radius, padding, border and shadow, and
every font size (separately with `textFactor`). Apply it **last**, since it
multiplies the values set before it:

```dart
ChatTheme.fallback(scheme)
    .withMessageText(const TextStyle(fontSize: 14))
    .scaled(1.2, textFactor: 1.1)
```

Widgets read the theme in `build`, so rebuilding `ThemeData` with a new
factor refreshes the whole chat. With a screen-size package such as
`flutter_screenutil`, build the theme inside `ScreenUtilInit`:

```dart
ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (context, child) => MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      extensions: [
        ChatTheme.fallback(scheme).scaled(
          ScreenUtil().scaleWidth,
          textFactor: ScreenUtil().scaleText,
        ),
      ],
    ),
    home: child,
  ),
  child: const InboxPage(),
)
```

Your own chat widgets (custom messages, headers) can follow the same scale
with `ChatTheme.of(context).size(12)` and `.fontSize(14)`.

The example app has a live style sheet (palette button): presets, colors,
dark mode, scale, message font size, bubble radius, shadows and borders,
tile layout and radius, and square avatars, applied to the screen behind
it. See `example/lib/style/style_settings.dart` for how each control maps
to the theme.

## Bubble

Colors, gradient, radius, border and shadows are in `ChatBubbleStyle` (see
Theme). For anything else, replace the bubble while keeping the content,
reply preview, time and status the kit builds inside it:

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
types.

### Several cards for one type

When one type has variants (a product offer, a service quote, ...), or the
widget depends on the data, use the `customBuilder` resolver. It runs for
types without a `customBuilders` entry; return null to fall back to the
unsupported view:

```dart
ChatBuilders(
  customBuilder: (context, m) {
    final message = m.message as CustomMessage;
    if (message.customType != 'offer') return null;
    return switch (message.data['variant']) {
      'product' || null => ProductOfferCard(message: m),
      'quote' => QuoteCard(message: m),
      _ => null, // a variant this app version does not know
    };
  },
)
```

### Inside the regular bubble

By default a custom widget replaces the whole bubble. List the type in
`bubbledCustomTypes` to draw it inside the default bubble instead, with the
reply preview, time and status ticks:

```dart
ChatBuilders(
  customBuilders: {'booking': (context, m) => BookingCard(message: m)},
  bubbledCustomTypes: const {'booking'},
)
```

Inside a bubble, read the side's colors so the content stays readable on
any theme: `ChatTheme.of(context).bubble(isMine: m.isMine).textStyle`.

The example app shows all three: a product offer and a quote (one `offer`
type, two cards) and a booking inside a bubble.

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

Tabs, chips and labels (for example an "Archived" list) are filters on the
controller: `kit.inbox(filter: RoomFilter.groups)` or
`inbox.setFilter(const RoomFilter(labels: {'archived'}))`. See
[several chat lists](adapters/mixing.md#several-chat-lists-from-one-backend).

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
- `RoomTile`, `RoomAvatar`, `InboxSearchBar`, `RoomSwipeActions`,
  `ChatUnreadBadge`
- `ChatAvatar`, `DatePill`, `ChatChip`

All of them read state from `ChatRoomController` / `InboxController`, which
you can also use with any widgets of your own.
