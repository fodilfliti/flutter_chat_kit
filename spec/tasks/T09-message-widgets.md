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

- [ ] Widget tests: a `CustomMessage('offer')` renders through `customBuilders`; missing builder renders unsupported view; `bubbleBuilder` wraps default; reply preview tap calls `jumpToMessage`; reactions toggle; actions sheet contains app-added action; failed message shows retry
- [ ] Golden-free; semantics labels on ticks and actions

## Do not

- Put media rendering here (T10)
- Hard-code colors (use `ChatTheme`)
