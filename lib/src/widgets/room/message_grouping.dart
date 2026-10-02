import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/builders/message_context.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';

/// One row of the message list. Lists are newest first: index 0 is drawn
/// at the bottom.
@immutable
sealed class ChatListItem {
  const ChatListItem();

  /// Stable identity across rebuilds, used for widget keys.
  Object get key;
}

final class MessageListItem extends ChatListItem {
  const MessageListItem({
    required this.message,
    required this.groupPosition,
    required this.messageIndex,
  });

  final Message message;
  final GroupPosition groupPosition;

  /// Index of [message] in `ChatRoomController.messages`.
  final int messageIndex;

  @override
  Object get key => message.localId;
}

/// Drawn above the first message of [day] (a local date at midnight).
final class DateSeparatorItem extends ChatListItem {
  const DateSeparatorItem(this.day);

  final DateTime day;

  @override
  Object get key => (#day, day.year, day.month, day.day);
}

/// Drawn above the first message that was unread when the room opened.
final class UnreadDividerItem extends ChatListItem {
  const UnreadDividerItem();

  @override
  Object get key => #unread;
}

/// Turns [messages] (newest first) into list rows: messages with their
/// [GroupPosition], a [DateSeparatorItem] above the first message of each
/// local day, and an [UnreadDividerItem] above the message at
/// [unreadDividerCursor].
///
/// The separator above the oldest message is only added at the start of
/// history ([isStartOfHistory]); otherwise older messages of the same day
/// may still load.
List<ChatListItem> buildChatListItems(
  List<Message> messages, {
  required Duration groupingWindow,
  MessageCursor? unreadDividerCursor,
  bool isStartOfHistory = true,
}) {
  final items = <ChatListItem>[];
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final newer = i > 0 ? messages[i - 1] : null;
    final older = i + 1 < messages.length ? messages[i + 1] : null;
    items.add(
      MessageListItem(
        message: message,
        groupPosition: GroupPosition.of(
          message,
          window: groupingWindow,
          older: older,
          newer: newer,
        ),
        messageIndex: i,
      ),
    );
    if (unreadDividerCursor != null && message.cursor == unreadDividerCursor) {
      items.add(const UnreadDividerItem());
    }
    final day = localDay(message.createdAt);
    if (older == null) {
      if (isStartOfHistory) items.add(DateSeparatorItem(day));
    } else if (localDay(older.createdAt) != day) {
      items.add(DateSeparatorItem(day));
    }
  }
  return items;
}

/// Midnight of the local day of [time].
DateTime localDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}
