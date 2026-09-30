# T09 — Message widgets

## Goal

Default rendering for every non-media message part, all routed through `ChatBuilders` so apps can replace or wrap each one, including the card/bubble itself and custom message types (for example an offer card).

## Read first

- [../decisions.md](../decisions.md) D7
- valizex `widgets/contact_chat_widgets/message_bubble_widget.dart`, `ExpandableTextMessage.dart`, `group_chat_widgets/MessageBubble.dart` (reply popup), `offer_reply_preview.dart`
- lightnessword `widgets/chat_bubble_widget.dart` (sender name only at the start of a run)

## Depends on

T08.

## Deliverables

```text
lib/src/widgets/room/message_bubble.dart         MessageBubble (shape by GroupPosition + isMine, tail corner)
lib/src/widgets/room/message_content.dart        dispatch: sealed switch -> builder or default; customBuilders[customType]
lib/src/widgets/messages/text_message_view.dart  expandable text, links/emails/phones tappable (onLinkTap), emoji-only large
lib/src/widgets/messages/file_message_view.dart  icon by extension, name, size, progress ring
lib/src/widgets/messages/system_message_view.dart
lib/src/widgets/messages/deleted_message_view.dart
lib/src/widgets/messages/unsupported_message_view.dart   CustomMessage without a builder
lib/src/widgets/room/status_ticks.dart           pending clock, sent ✓, delivered ✓✓, seen ✓✓ colored, failed ! + retry
lib/src/widgets/room/reply_preview.dart          quoted message inside bubble; tap -> jumpToMessage
lib/src/widgets/room/reactions_bar.dart          chips with counts; mine highlighted; tap toggles
lib/src/widgets/room/message_actions_sheet.dart  quick reactions row + actions (reply, copy, edit, delete, retry + app actions)
lib/src/widgets/room/swipe_to_reply.dart
lib/src/widgets/room/chat_avatar.dart            image or initials, deterministic color
test/widgets/message_widgets_test.dart
```

## Behaviour

- Content resolution order: `builders.messageBuilder` (whole row) → `builders.bubbleBuilder(defaultBubble)` → per-type builder (`textBuilder`, …, `customBuilders[type]`) → default view.
- Every builder receives the default widget so apps can wrap it.
- Bubble max width `theme.maxBubbleWidthFactor`; timestamp + ticks inline at bottom-right of text bubbles; overlay pill on media.
- Author name + avatar in groups: name on `first`/`single`, avatar on `last`/`single` (reserve width on others to keep alignment).
- Edited label, failed state with tap-to-retry, selection overlay in multi-select mode.
- Long press → `MessageActionsSheet` built from defaults filtered by capability (edit only own text, delete own, copy text) then `builders.messageActions(defaults)`.

## Done when

- [x] Widget tests: a `CustomMessage('offer')` renders through `customBuilders`; missing builder renders unsupported view; `bubbleBuilder` wraps default; reply preview tap calls `jumpToMessage`; reactions toggle; actions sheet contains app-added action; failed message shows retry
- [x] Golden-free; semantics labels on ticks and actions

## As built

- `MessageContent` is the default rendering; `ChatMessageList` always uses it (its T08 `contentBuilder` hook is gone: `ChatBuilders` covers every layer).
  - Order: `bubbleBuilder(MessageBubble)` → per-type builder (`textBuilder`, `fileBuilder`, `imageBuilder`, …) → default view.
  - A `CustomMessage` with a `customBuilders` entry renders without a bubble (apps draw their own card); without one it shows `UnsupportedMessageView` (`unsupportedBuilder`).
  - System messages are a centered `SystemMessageView` pill (`systemBuilder`).
  - Reactions (`reactionsBuilder`) and the failed notice with a retry button sit under the bubble.
- Time and ticks (`MessageMeta`) sit inline after short texts and wrap to their own line after long ones (a `Wrap`, no custom render object); media and files put them on a line below. `timestampBuilder` and `statusBuilder` wrap each part.
- `MessageContext` gained:
  - `currentUserId`;
  - `repliedToAuthor`;
  - `displayStatus`: the list passes `ChatRoomController.effectiveStatus`, and `status` returns it;
  - `isSelectionMode`.
- Callbacks on `ChatMessageList` (and `MessageContent`):
  - `onReply` enables swipe-to-reply (with `ChatConfig.swipeToReply`) and the reply action;
  - `onEdit` enables the edit action;
  - `onLinkTap(Uri)` (`https:`, `mailto:`, `tel:`), for example with `url_launcher` in the app;
  - `onAttachmentTap(message, attachment)`.
  Reply preview taps call `jumpToMessage`; reaction chips and quick reactions call `react` (when `ChatConfig.enableReactions`); retry calls `retry`.
- Long press opens `MessageActionsSheet` unless `onMessageLongPress` is set.
  - `MessageActionsSheet.defaults(...)` filters by capability: reply for confirmed messages; copy when there is text or a caption; edit for own confirmed text, image or video; retry for own failed messages; delete for own messages (pending or failed ones are discarded).
  - `builders.messageActions` edits the list. Copy writes to the clipboard and shows `strings.copied` in a `SnackBar` when a `ScaffoldMessenger` exists.
- While any message is selected, taps and long presses toggle selection and rows show a check circle.
- `TextMessageView`:
  - `linkPattern` / `uriOf` detect URLs (`http(s)://`, `www.`), e-mails, and phone numbers with 8–15 digits;
  - `isEmojiOnly` covers one to three emoji, drawn at 2.4× size;
  - texts over `collapseAfter` (700) characters collapse behind `readMore` / `readLess`.
- `FileMessageView.iconFor(attachment)` picks the icon by extension, then by MIME type. The upload ring only listens while the message is local.
- `ReplyPreview(snippet, title, onTap, onClose)` is shared with the composer (T11). `messageSnippet(message, strings)` and `copyableText(message)` live in `widgets/common/message_snippet.dart` for the inbox too.
- `ChatAvatar` stays in `widgets/common/` (from T08).
- New `ChatStrings`: `readMore`, `readLess`, `replyUnavailable`, `statusPending`, `statusSent`, `statusDelivered`, `statusSeen`, `messageOptions`, `reaction(emoji, count)`, `reactWith(emoji)`.
- Image, video and audio messages show an icon-and-label placeholder (plus caption) until T10 plugs in the media views.

## Do not

- Put media rendering here (T10)
- Hard-code colors (use `ChatTheme`)
