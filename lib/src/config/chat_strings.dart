import 'package:flutter/foundation.dart';

/// Every user-facing text the kit shows. English by default; apps pass
/// their own localized values.
///
/// Plural or dynamic text is a function so apps can localize it properly.
///
/// Pass the same instance to `InboxView.strings` and
/// `ChatRoomView.strings`. Set only the texts you change:
///
/// ```dart
/// final strings = ChatStrings(
///   typeMessage: 'Écrire un message',
///   typing: (names) => '${names.join(', ')} écrit…',
///   system: (code, args) => switch (code) {
///     'member_joined' => '${args['name']} a rejoint le groupe',
///     _ => ChatStrings.defaultSystem(code, args),
///   },
/// );
/// ```
@immutable
class ChatStrings {
  /// English texts, each replaceable by name.
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
    this.fileUnavailable =
        'This file is no longer available. Delete it '
        'and send it again.',
    this.compressing = 'Compressing',
    this.readMore = 'Read more',
    this.readLess = 'Show less',
    this.replyUnavailable = 'Original message unavailable',
    this.statusPending = 'Sending',
    this.statusSent = 'Sent',
    this.statusDelivered = 'Delivered',
    this.statusSeen = 'Seen',
    this.messageOptions = 'Message options',
    this.save = 'Save',
    this.saved = 'Saved',
    this.download = 'Download',
    this.downloadFailed = "Couldn't download",
    this.play = 'Play',
    this.pause = 'Pause',
    this.close = 'Close',
    this.attach = 'Attach',
    this.removeAttachment = 'Remove',
    this.recordVoice = 'Record voice message',
    this.holdToRecord = 'Hold to record, release to send',
    this.microphoneDenied = 'Allow microphone access to record',
    this.slideUpToLock = 'Slide up to lock',
    this.stopRecording = 'Stop recording',
    this.back = 'Back',
    this.forward = 'Forward',
    this.select = 'Select',
    this.pin = 'Pin',
    this.unpin = 'Unpin',
    this.mute = 'Mute',
    this.unmute = 'Unmute',
    this.clearSearch = 'Clear search',
    this.noResults = 'No results',
    this.loadChatsFailed = "Couldn't load conversations",
    this.switchProfile = 'Switch profile',
    this.businessProfile = 'Business',
    this.typing = defaultTyping,
    this.system = defaultSystem,
    this.lastSeen = defaultLastSeen,
    this.photos = defaultPhotos,
    this.reaction = defaultReaction,
    this.reactWith = defaultReactWith,
    this.playbackSpeed = defaultPlaybackSpeed,
    this.moreMedia = defaultMoreMedia,
    this.mediaPosition = defaultMediaPosition,
    this.members = defaultMembers,
    this.selectedCount = defaultSelectedCount,
    this.previewWithAuthor = defaultPreviewWithAuthor,
    this.unreadCount = defaultUnreadCount,
    this.customPreview,
  });

  /// Hint of the empty composer field. Default: `Message`.
  final String typeMessage;

  /// Date separator for today. Default: `Today`.
  final String today;

  /// Date separator and room time for yesterday. Default: `Yesterday`.
  final String yesterday;

  /// Unread divider label.
  final String newMessages;

  /// Message action that starts a reply. Default: `Reply`.
  final String reply;

  /// Message action that copies the text. Default: `Copy`.
  final String copy;

  /// Snack bar after copying. Default: `Copied`.
  final String copied;

  /// Message action that edits the text. Default: `Edit`.
  final String edit;

  /// Message action that deletes the message. Default: `Delete`.
  final String delete;

  /// Retry action of a failed message and of the inbox error state.
  /// Default: `Retry`.
  final String retry;

  /// Tooltip that closes the reply or edit banner and ends selection.
  /// Default: `Cancel`.
  final String cancel;

  /// Tooltip of the send button. Default: `Send`.
  final String send;

  /// Label under a failed message and its tick. Default: `Failed to send`.
  final String failedToSend;

  /// Placeholder of a deleted message, also in previews. Default:
  /// `This message was deleted`.
  final String messageDeleted;

  /// A custom message with no builder, and its preview when
  /// [customPreview] gives none. Default: `Unsupported message`.
  final String unsupportedMessage;

  /// Label next to the time of an edited message.
  final String edited;

  /// Composer banner title while editing.
  final String editing;

  /// Author prefix of the current user's last message in the inbox.
  final String you;

  /// App bar subtitle of a direct room while the peer is online. Default:
  /// `online`.
  final String online;

  /// Hint while recording a voice note. Default: `Slide to cancel`.
  final String slideToCancel;

  /// Hint of the inbox search field. Default: `Search`.
  final String searchChats;

  /// Inbox with no rooms. Default: `No conversations yet`.
  final String noChats;

  /// Room with no messages. Default: `Say hello`.
  final String noMessages;

  /// Message list error. Not shown by the current widgets. Default:
  /// `Couldn't load messages`.
  final String loadFailed;

  /// Shown above the oldest message once the whole history is loaded.
  final String startOfConversation;

  /// Tooltip of the scroll-to-bottom button.
  final String scrollToBottom;

  /// A single photo. Not shown by the current widgets, which use
  /// [photos]. Default: `Photo`.
  final String photo;

  /// Attachment sheet option and preview of a video without caption.
  /// Default: `Video`.
  final String video;

  /// Preview of a voice note. Default: `Voice message`.
  final String voice;

  /// Attachment sheet option, and the name of a file that has none.
  /// Default: `File`.
  final String file;

  /// Attachment sheet option that opens the camera. Default: `Camera`.
  final String camera;

  /// Attachment sheet option that opens the gallery. Default: `Gallery`.
  final String gallery;

  /// Snack bar when a file exceeds `ChatConfig.maxAttachmentBytes`.
  /// Default: `File is too large`.
  final String attachmentTooLarge;

  /// Snack bar when retrying a send whose file can't be read anymore (on
  /// the web, a file picked before the page reloaded). Default:
  /// `This file is no longer available. Delete it and send it again.`
  final String fileUnavailable;

  /// Label on a video bubble while `ChatConfig.compressVideo` runs.
  /// Default: `Compressing`.
  final String compressing;

  /// Expands and collapses a long text message.
  final String readMore;

  /// Collapses an expanded text message. Default: `Show less`.
  final String readLess;

  /// Reply preview of a message that is not loaded or was removed.
  final String replyUnavailable;

  /// Accessibility labels of the delivery ticks (failed uses
  /// [failedToSend]).
  final String statusPending;

  /// Accessibility label of the single tick. Default: `Sent`.
  final String statusSent;

  /// Accessibility label of the double tick. Default: `Delivered`.
  final String statusDelivered;

  /// Accessibility label of the seen tick. Default: `Seen`.
  final String statusSeen;

  /// Accessibility label of the long-press actions sheet.
  final String messageOptions;

  /// Exports a media file or document.
  final String save;

  /// Snack bar after a file was saved. Default: `Saved`.
  final String saved;

  /// Button on media that downloads on tap (see `ChatConfig.autoDownload`).
  /// Default: `Download`.
  final String download;

  /// Snack bar when saving a file failed, and the retry button of media
  /// that failed to download. Default: `Couldn't download`.
  final String downloadFailed;

  /// Voice message and video controls.
  final String play;

  /// Pause button of voice messages and videos. Default: `Pause`.
  final String pause;

  /// Closes the media viewer and the composer banner.
  final String close;

  /// Composer: attachment button, removing a staged file.
  final String attach;

  /// Tooltip that removes a staged file from the composer. Default:
  /// `Remove`.
  final String removeAttachment;

  /// Composer voice button: tooltip, and the hint after a short tap or a
  /// too-short recording.
  final String recordVoice;

  /// Hint after a short tap on the mic. Default:
  /// `Hold to record, release to send`.
  final String holdToRecord;

  /// Hint when microphone permission is denied. Default:
  /// `Allow microphone access to record`.
  final String microphoneDenied;

  /// Accessibility label of the lock handle shown while recording.
  /// Default: `Slide up to lock`.
  final String slideUpToLock;

  /// Tooltip that stops a locked recording. Default: `Stop recording`.
  final String stopRecording;

  /// Tooltip of the room app bar back button.
  final String back;

  /// Selection app bar action (shown only when the app handles forwarding).
  final String forward;

  /// Message action that starts multi-selection.
  final String select;

  /// Inbox swipe actions.
  final String pin;

  /// Inbox action on a pinned room. Default: `Unpin`.
  final String unpin;

  /// Inbox action, and the label of the muted icon. Default: `Mute`.
  final String mute;

  /// Inbox action on a muted room. Default: `Unmute`.
  final String unmute;

  /// Inbox search: clear button tooltip and empty result.
  final String clearSearch;

  /// Inbox with no room matching the search. Default: `No results`.
  final String noResults;

  /// Inbox error state.
  final String loadChatsFailed;

  /// `ChatProfileMenuButton`: tooltip, and the subtitle of business
  /// profiles.
  final String switchProfile;

  /// Subtitle of business profiles in the profile menu. Default:
  /// `Business`.
  final String businessProfile;

  /// Names of the users currently typing, in arrival order. Never empty.
  final String Function(List<String> names) typing;

  /// Text for a `SystemMessage` (its `code` and `args`), shown centered
  /// in the room and in previews. The default is [defaultSystem]. Map
  /// your backend's codes here:
  ///
  /// ```dart
  /// system: (code, args) => switch (code) {
  ///   'member_joined' => '${args['name']} joined',
  ///   'room_renamed' => 'Renamed to ${args['title']}',
  ///   _ => ChatStrings.defaultSystem(code, args),
  /// },
  /// ```
  final String Function(String code, Map<String, Object?> args) system;

  /// App bar subtitle; `when` is already formatted by `ChatFormatters`.
  final String Function(String when) lastSeen;

  /// Inbox preview for an image message with `count` images.
  final String Function(int count) photos;

  /// Accessibility label of a reaction chip.
  final String Function(String emoji, int count) reaction;

  /// Tooltip of a quick-reaction button.
  final String Function(String emoji) reactWith;

  /// Voice message speed button, for example `1.5x`.
  final String Function(double speed) playbackSpeed;

  /// Overlay on the last cell of an image grid with `count` more images.
  final String Function(int count) moreMedia;

  /// Media viewer title, for example `3 of 12` (`index` starts at 1).
  final String Function(int index, int total) mediaPosition;

  /// Group app bar subtitle.
  final String Function(int count) members;

  /// Selection app bar title.
  final String Function(int count) selectedCount;

  /// Inbox preview prefixed with its author (`You` or a group member).
  final String Function(String author, String text) previewWithAuthor;

  /// Accessibility label of the inbox unread badge.
  final String Function(int count) unreadCount;

  /// One-line text of a `CustomMessage` for the inbox and reply previews.
  /// [unsupportedMessage] is used when this is null or returns null.
  ///
  /// ```dart
  /// customPreview: (type, data) => switch (type) {
  ///   'offer' => 'Offer: ${data['price']} ${data['currency']}',
  ///   _ => null,
  /// },
  /// ```
  final String? Function(String customType, Map<String, Object?> data)?
  customPreview;

  /// `Ann is typing`, `Ann and Bob are typing`, `3 people are typing`.
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

  /// `last seen <when>`.
  static String defaultLastSeen(String when) => 'last seen $when';

  /// `Photo` or `<count> photos`.
  static String defaultPhotos(int count) =>
      count == 1 ? 'Photo' : '$count photos';

  /// `<emoji>, 1 reaction` or `<emoji>, <count> reactions`.
  static String defaultReaction(String emoji, int count) =>
      count == 1 ? '$emoji, 1 reaction' : '$emoji, $count reactions';

  /// `React with <emoji>`.
  static String defaultReactWith(String emoji) => 'React with $emoji';

  /// `1x`, `1.5x`, `2x`.
  static String defaultPlaybackSpeed(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
    return '${text}x';
  }

  /// `+<count>`.
  static String defaultMoreMedia(int count) => '+$count';

  /// `<index> of <total>`.
  static String defaultMediaPosition(int index, int total) =>
      '$index of $total';

  /// `1 member` or `<count> members`.
  static String defaultMembers(int count) =>
      count == 1 ? '1 member' : '$count members';

  /// The bare count.
  static String defaultSelectedCount(int count) => '$count';

  /// `<author>: <text>`.
  static String defaultPreviewWithAuthor(String author, String text) =>
      '$author: $text';

  /// `1 unread message` or `<count> unread messages`.
  static String defaultUnreadCount(int count) =>
      count == 1 ? '1 unread message' : '$count unread messages';
}
