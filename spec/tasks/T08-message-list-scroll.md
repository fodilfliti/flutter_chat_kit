# T08 — ChatMessageList (scroll engine)

## Goal

A message list that scrolls smoothly and correctly: newest at the bottom, older pages load without moving the viewport, new messages only pull the user down when appropriate, and jump-to-message works for anything in history.

## Read first

- [../decisions.md](../decisions.md) D3; [../invariants.md](../invariants.md) (UI)
- `super_sliver_list` docs: `SuperSliverList`, `ListController.jumpToItem` / `animateToItem`, `ExtentEstimationProvider`
- valizex `chat_page.dart`: `_onItemPositionsChanged` (preload, button visibility) and `_scrollToMessage` (load until found, retry, highlight)

## Depends on

T06, T07.

## Deliverables

```text
lib/src/widgets/room/message_list.dart          ChatMessageList
lib/src/widgets/room/message_row.dart           MessageRow (layout: avatar, name, bubble, status; no content)
lib/src/widgets/room/date_separator.dart
lib/src/widgets/room/unread_divider.dart
lib/src/widgets/room/scroll_to_bottom_button.dart
lib/src/widgets/room/typing_indicator.dart
lib/src/widgets/room/floating_date_header.dart
lib/src/widgets/room/message_grouping.dart      pure function: GroupPosition + separators
test/widgets/message_list_test.dart
```

## Public API

```dart
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    required this.controller, this.builders = const ChatBuilders(), this.config, this.strings,
    this.onMessageTap, this.onMessageLongPress, this.onAvatarTap, this.padding,
    // T09 replaced contentBuilder with MessageContent + ChatBuilders, and added
    // onReply, onEdit, onLinkTap, onAttachmentTap.
  });
}
```

## Behaviour

1. `CustomScrollView(reverse: true)` → `SuperSliverList` with `SliverChildBuilderDelegate`; item keys `ValueKey(message.localId)`; `findChildIndexCallback` maps `localId` → index so reordering/reconciliation never rebuilds from scratch.
2. Items are derived once per `messages` change (not per build): message rows plus date separators and the unread divider, computed by `message_grouping.dart`.
3. Top-of-history loader and "beginning of conversation" as the last sliver item.
4. Scroll listener (throttled to one frame): `atBottom = pixels <= 48`; report `controller.onViewportChanged(atBottom:)`; preload when the last built index ≥ `items.length - config.preloadThreshold`; show/hide `ScrollToBottomButton` with `newMessagesCount` badge; tap → `returnToLatest()` if detached, then animate to 0.
5. Auto-scroll on new newest item: `always` → animate to 0; `whenMineOrAtBottom` → animate if the new message is mine or `atBottom`; `never` → badge only.
6. Jump: `jumpToMessage(id)` → wait one frame → re-scan index → `listController.animateToItem(index, alignment: 0.3)` → highlight via `highlightedId` (`AnimatedContainer` color fade).
7. Typing indicator is the first sliver (visually at the bottom) when `typingUserIds` is not empty.
8. `keyboardDismissBehavior: onDrag`; `ClampingScrollPhysics` on Android, platform default elsewhere; `cacheExtent` tuned (~1.5 screens).
9. Floating date header shows the date of the topmost visible message while scrolling, fades out when idle.

## Done when

- [x] Widget tests: loading older keeps the first visible message at the same screen offset; a new incoming message while scrolled up does not move the list and increments the badge; own message scrolls to bottom; jump to a message not loaded triggers `fetchAround` and highlights it; separators appear between days; grouping positions correct
- [ ] Manual check in example with 5 000 messages: no dropped frames on fling (profile mode) — pending until the example app (T13)

## As built

- **Center-anchored layout.** A single `SuperSliverList` shifts the viewport when an item is inserted at index 0, because it sums estimated extents. So the list is split at an anchor cursor (the newest message when the window opened) into two slivers of one reversed `CustomScrollView`:
  - the *older* sliver (anchor and older, newest first) is the `center`, starting at scroll offset 0 and growing up;
  - the *newer* sliver (after the anchor, oldest first) sits before the center and grows down, so the bottom is `minScrollExtent` (negative once newer messages arrive).
  Incoming messages and newer pages extend the newer sliver; older pages extend the older one. Neither moves what is on screen. The anchor resets to the newest message when a new slice replaces the messages (jump, return to latest).
- "At bottom" is `pixels <= minScrollExtent + 48`, and scrolling to the bottom targets `minScrollExtent`. After the first layout the list jumps to the true bottom, because the bottom padding sits below the center.
- **Jump.** `ChatMessageListState.jumpToMessage(id)` calls the controller, re-anchors if the target was not loaded, waits a frame, then:
  - animates to the target's offset, estimated from the sliver's measured or estimated row extents;
  - reveals the built row with `Scrollable.ensureVisible` at alignment `0.5` (centered instead of `0.3`).
  `ListController.animateToItem` is not used: its precise final step miscomputes offsets for slivers placed before the center.
- `ChatMessageListState.scrollToBottom()` (returns to latest when detached) and `ChatMessageList.maybeOf(context)` let the screen drive the list. `showsScrollToBottom` is a `ValueListenable<bool>`.
- `ChatMessageList` also takes `formatters` (date labels). `ChatStrings` gained `startOfConversation` and `scrollToBottom`; every label comes from `ChatStrings`.
- `buildChatListItems(messages, {groupingWindow, unreadDividerCursor, isStartOfHistory})` returns a sealed `ChatListItem` (`MessageListItem`, `DateSeparatorItem`, `UnreadDividerItem`) with stable keys; the last date separator only shows at the start of history.
- `MessageRow(message: MessageContext, content, maxContentWidth, showAvatar, avatar, authorName, onTap, onLongPress)` handles spacing by group position, highlight and selection color (`AnimatedContainer`), centered system messages, and the avatar on the last row of a group.
- `ChatAvatar(name, url, size)` (network image with initials fallback) is shared with the inbox.
- Upload progress is only listened to for local (pending) messages; confirmed rows get a constant `null` progress.
- Until T09, rows use a plain fallback bubble with text from `ChatStrings`.

## Do not

- Use `shrinkWrap: true` or jump-to-max loops
- Call `setState` on the whole list for upload or audio progress
