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
    this.contentBuilder,     // T09 injects default message content; placeholder text until then
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

- [ ] Widget tests: loading older keeps the first visible message at the same screen offset; a new incoming message while scrolled up does not move the list and increments the badge; own message scrolls to bottom; jump to a message not loaded triggers `fetchAround` and highlights it; separators appear between days; grouping positions correct
- [ ] Manual check in example with 5 000 messages: no dropped frames on fling (profile mode)

## Do not

- Use `shrinkWrap: true` or jump-to-max loops
- Call `setState` on the whole list for upload or audio progress
