# T07 — Theme, config, strings, formatters, builders

## Goal

The whole customization surface, defined before the widgets that use it. Can be built in parallel with T02–T06.

## Read first

- [../decisions.md](../decisions.md) D7, D9; [../invariants.md](../invariants.md) (UI)
- Flutter `ThemeExtension` docs

## Depends on

T01.

## Deliverables

```text
lib/src/config/chat_theme.dart        ChatTheme extends ThemeExtension<ChatTheme>
lib/src/config/chat_config.dart       ChatConfig, AutoScrollPolicy
lib/src/config/chat_strings.dart      ChatStrings (English defaults)
lib/src/config/chat_formatters.dart   ChatFormatters
lib/src/builders/message_context.dart MessageContext, GroupPosition
lib/src/builders/chat_builders.dart   ChatBuilders, MessageAction, typedefs
lib/src/builders/inbox_builders.dart  InboxBuilders, RoomContext
test/config/*_test.dart
```

## Public API

```dart
class ChatTheme extends ThemeExtension<ChatTheme> {
  const ChatTheme({
    this.outgoingBubbleColor, this.incomingBubbleColor, this.outgoingTextStyle, this.incomingTextStyle,
    this.bubbleRadius, this.tailRadius, this.bubblePadding, this.maxBubbleWidthFactor = 0.78,
    this.avatarSize = 32, this.messageSpacing = 2, this.groupSpacing = 10,
    this.dateSeparatorStyle, this.composerDecoration, this.highlightColor, this.statusColors, ...
  });
  static ChatTheme of(BuildContext context); // extension ?? ChatTheme.fallback(Theme.of(context).colorScheme)
  factory ChatTheme.fallback(ColorScheme scheme);
  copyWith(...); lerp(...);
}

enum AutoScrollPolicy { always, whenMineOrAtBottom, never }

class ChatConfig {
  const ChatConfig({
    this.pageSize = 30, this.roomsPageSize = 20, this.preloadThreshold = 10,
    this.autoScrollPolicy = AutoScrollPolicy.whenMineOrAtBottom,
    this.groupingWindow = const Duration(minutes: 3),
    this.showAvatarsInDirect = false, this.showAuthorNamesInGroup = true,
    this.swipeToReply = true, this.enableReactions = true, this.quickReactions = const ['👍','❤️','😂','😮','😢','🙏'],
    this.markReadWhenAtBottom = true, this.highlightDuration = const Duration(milliseconds: 1500),
    this.typingThrottle = const Duration(seconds: 3), this.typingTimeout = const Duration(seconds: 5),
    this.searchDebounce = const Duration(milliseconds: 350),
    this.maxCachedMessagesPerRoom, this.userCacheTtl = const Duration(hours: 12),
    this.maxAttachmentBytes, this.minVoiceDuration = const Duration(seconds: 1),
  });
}

class ChatStrings {
  const ChatStrings({this.typeMessage = 'Message', this.today = 'Today', this.yesterday = 'Yesterday',
    this.newMessages = 'New messages', this.reply = 'Reply', this.copy = 'Copy', this.edit = 'Edit',
    this.delete = 'Delete', this.retry = 'Retry', this.failedToSend = 'Failed to send',
    this.messageDeleted = 'This message was deleted', this.edited = 'edited', this.online = 'online',
    this.slideToCancel = 'Slide to cancel', this.searchChats = 'Search', this.noChats = 'No conversations yet',
    this.noMessages = 'Say hello', this.photo = 'Photo', this.video = 'Video', this.voice = 'Voice message',
    this.file = 'File', this.camera = 'Camera', this.gallery = 'Gallery', ...});
  // Plural / dynamic text is a function so apps can localize properly:
  final String Function(List<String> names) typing;   // "Ana is typing", "Ana and Bo are typing", "3 people are typing"
  final String Function(String code, Map<String, Object?> args) system;
}

class ChatFormatters {
  const ChatFormatters({this.time, this.dateSeparator, this.duration, this.fileSize, this.lastSeen});
  // defaults use intl DateFormat with the ambient locale
}

enum GroupPosition { single, first, middle, last }

@immutable
class MessageContext {
  final Message message; final ChatUser? author; final bool isMine; final GroupPosition groupPosition;
  final bool isSelected; final bool isHighlighted; final ChatRoom? room; final List<RoomMember> seenBy;
  final MessageStatus status; final ValueListenable<double?> uploadProgress; final Message? repliedTo;
  final ChatRoomController controller; final int index;
}

typedef MessageWidgetBuilder = Widget Function(BuildContext context, MessageContext mc, Widget defaultChild);
typedef CustomMessageBuilder = Widget Function(BuildContext context, MessageContext mc);
typedef MessageActionsBuilder = List<MessageAction> Function(BuildContext context, MessageContext mc, List<MessageAction> defaults);

class ChatBuilders {
  const ChatBuilders({
    this.messageBuilder, this.bubbleBuilder, this.textBuilder, this.imageBuilder, this.videoBuilder,
    this.audioBuilder, this.fileBuilder, this.systemBuilder, this.deletedBuilder, this.unsupportedBuilder,
    this.customBuilders = const {}, this.avatarBuilder, this.authorNameBuilder, this.statusBuilder,
    this.timestampBuilder, this.replyPreviewBuilder, this.reactionsBuilder, this.dateSeparatorBuilder,
    this.unreadDividerBuilder, this.typingBuilder, this.scrollToBottomBuilder, this.emptyBuilder,
    this.loadingBuilder, this.errorBuilder, this.composerBuilder, this.appBarBuilder, this.messageActions,
  });
}

class MessageAction { const MessageAction({required this.id, required this.label, required this.icon, required this.onTap, this.isDestructive = false}); }
```

`InboxBuilders` mirrors this for the inbox: `tileBuilder`, `leadingBuilder`, `titleBuilder`, `subtitleBuilder`, `trailingBuilder`, `emptyBuilder`, `loadingBuilder`, `searchBarBuilder`, `swipeActions`.

### As built

- `ChatTheme` fields are non-nullable so widgets never null-check. Apps build one with `ChatTheme.fallback(scheme).copyWith(...)`. `ChatTheme.of` is a factory. `composerDecoration` / `statusColors` became plain colors and styles (`composerInputColor`, `composerHintStyle`, `statusColor`, `seenColor`, `failedColor`) so `lerp` stays exact. Added meta, reaction, badge and inbox row styles.
- `MessageContext.controller` is **added in T06** (the controller doesn't exist yet). `GroupPosition.of(message, older:, newer:, window:)` computes grouping: same author, same local day, within the window, no system messages.
- `ChatBuilders.appBarActions` adds actions without replacing the app bar. `MessageAction` has well-known ids (`replyId`, `copyId`, ...) for filtering defaults.
- `ChatStrings` adds `copied`, `cancel`, `send`, `editing`, `you`, `loadFailed`, `unsupportedMessage`, `attachmentTooLarge`, and the functions `lastSeen(when)` and `photos(count)`. The function defaults are static tear-offs, so the constructor stays `const`.
- `ChatFormatters` exposes `formatTime`, `formatDateSeparator`, `formatRoomTime`, `formatLastSeen`, `formatDuration` and `formatFileSize`. An uninitialized or unknown locale falls back to intl's default instead of throwing.
- `InboxBuilders` adds `errorBuilder`; swipe actions use `RoomAction`.

## Done when

- [x] `ChatTheme.of` falls back to `ColorScheme` without an extension; `lerp` works for theme animation
- [x] Default formatters tested (today / yesterday / weekday / date; `1.2 MB`; `0:42`)
- [x] `ChatStrings.typing` default handles 1, 2, 3+ names
- [x] All exported; analyze clean

## Do not

- Depend on `flutter_scale_theme_kit` or `flutter_scale_kit`
- Hard-code user-facing English anywhere except `ChatStrings` defaults
