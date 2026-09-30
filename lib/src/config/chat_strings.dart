import 'package:flutter/foundation.dart';

/// Every user-facing text the kit shows. English by default; apps pass
/// their own localized values.
///
/// Plural or dynamic text is a function so apps can localize it properly.
@immutable
class ChatStrings {
  const ChatStrings({
    this.typeMessage = 'Message',
    this.today = 'Today',
    this.yesterday = 'Yesterday',
    this.newMessages = 'New messages',
    this.reply = 'Reply',
    this.copy = 'Copy',
    this.copied = 'Copied',
    this.edit = 'Edit',
    this.delete = 'Delete',
    this.retry = 'Retry',
    this.cancel = 'Cancel',
    this.send = 'Send',
    this.failedToSend = 'Failed to send',
    this.messageDeleted = 'This message was deleted',
    this.unsupportedMessage = 'Unsupported message',
    this.edited = 'edited',
    this.editing = 'Editing',
    this.you = 'You',
    this.online = 'online',
    this.slideToCancel = 'Slide to cancel',
    this.searchChats = 'Search',
    this.noChats = 'No conversations yet',
    this.noMessages = 'Say hello',
    this.loadFailed = "Couldn't load messages",
    this.startOfConversation = 'This is the start of the conversation',
    this.scrollToBottom = 'Scroll to latest',
    this.photo = 'Photo',
    this.video = 'Video',
    this.voice = 'Voice message',
    this.file = 'File',
    this.camera = 'Camera',
    this.gallery = 'Gallery',
    this.attachmentTooLarge = 'File is too large',
    this.typing = defaultTyping,
    this.system = defaultSystem,
    this.lastSeen = defaultLastSeen,
    this.photos = defaultPhotos,
  });

  final String typeMessage;
  final String today;
  final String yesterday;

  /// Unread divider label.
  final String newMessages;
  final String reply;
  final String copy;
  final String copied;
  final String edit;
  final String delete;
  final String retry;
  final String cancel;
  final String send;
  final String failedToSend;
  final String messageDeleted;
  final String unsupportedMessage;

  /// Label next to the time of an edited message.
  final String edited;

  /// Composer banner title while editing.
  final String editing;

  /// Author prefix of the current user's last message in the inbox.
  final String you;
  final String online;
  final String slideToCancel;
  final String searchChats;
  final String noChats;
  final String noMessages;
  final String loadFailed;

  /// Shown above the oldest message once the whole history is loaded.
  final String startOfConversation;

  /// Tooltip of the scroll-to-bottom button.
  final String scrollToBottom;
  final String photo;
  final String video;
  final String voice;
  final String file;
  final String camera;
  final String gallery;
  final String attachmentTooLarge;

  /// Names of the users currently typing, in arrival order. Never empty.
  final String Function(List<String> names) typing;

  /// Text for a `SystemMessage` (its `code` and `args`).
  final String Function(String code, Map<String, Object?> args) system;

  /// App bar subtitle; `when` is already formatted by `ChatFormatters`.
  final String Function(String when) lastSeen;

  /// Inbox preview for an image message with `count` images.
  final String Function(int count) photos;

  static String defaultTyping(List<String> names) {
    return switch (names.length) {
      0 => '',
      1 => '${names[0]} is typing',
      2 => '${names[0]} and ${names[1]} are typing',
      _ => '${names.length} people are typing',
    };
  }

  /// Uses `args['text']` when present, otherwise the raw code.
  static String defaultSystem(String code, Map<String, Object?> args) {
    final text = args['text'];
    return text is String && text.isNotEmpty ? text : code;
  }

  static String defaultLastSeen(String when) => 'last seen $when';

  static String defaultPhotos(int count) =>
      count == 1 ? 'Photo' : '$count photos';
}
