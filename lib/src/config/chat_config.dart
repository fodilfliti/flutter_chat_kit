import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';

/// When the message list scrolls to a newly arrived message.
enum AutoScrollPolicy {
  /// Always scroll to the newest message, even when the user was reading
  /// older ones.
  always,

  /// Scroll for the user's own messages, or when already at the bottom.
  /// Otherwise the "new messages" badge counts up.
  whenMineOrAtBottom,

  /// Never scroll; the "new messages" badge counts up instead.
  never,
}

/// Behaviour settings shared by the kit's controllers and widgets.
///
/// Pass it as `ChatKit.config`. Every field has a default, so set only
/// what differs:
///
/// ```dart
/// final kit = ChatKit(
///   currentUserId: uid,
///   source: source,
///   config: const ChatConfig(enableReactions: false, pageSize: 50),
/// );
/// ```
@immutable
class ChatConfig {
  /// Settings with the defaults listed on each field.
  const ChatConfig({
    this.pageSize = 30,
    this.roomsPageSize = 20,
    this.preloadThreshold = 10,
    this.autoScrollPolicy = AutoScrollPolicy.whenMineOrAtBottom,
    this.groupingWindow = const Duration(minutes: 3),
    this.showAvatarsInDirect = false,
    this.showAuthorNamesInGroup = true,
    this.showSentBy = true,
    this.swipeToReply = true,
    this.enableReactions = true,
    this.quickReactions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.markReadWhenAtBottom = true,
    this.highlightDuration = const Duration(milliseconds: 1500),
    this.typingThrottle = const Duration(seconds: 3),
    this.typingTimeout = const Duration(seconds: 5),
    this.searchDebounce = const Duration(milliseconds: 350),
    this.maxCachedMessagesPerRoom,
    this.userCacheTtl = const Duration(hours: 12),
    this.maxAttachmentBytes,
    this.minVoiceDuration = const Duration(seconds: 1),
    this.maxMediaCacheBytes = 500 * 1024 * 1024,
    this.autoDownload = const {AttachmentKind.image, AttachmentKind.audio},
  });

  /// Messages per fetch (the `limit` of `ChatSource.fetchMessages`).
  /// Defaults to 30.
  final int pageSize;

  /// Rooms per fetch (the `limit` of `ChatSource.fetchRooms`). Defaults
  /// to 20.
  final int roomsPageSize;

  /// Load older messages when this many items remain above the viewport.
  /// Defaults to 10.
  final int preloadThreshold;

  /// Whether the list scrolls to a new message. Defaults to
  /// [AutoScrollPolicy.whenMineOrAtBottom].
  final AutoScrollPolicy autoScrollPolicy;

  /// Consecutive messages by one author within this window are grouped:
  /// tighter spacing, one avatar and one name. Defaults to 3 minutes.
  final Duration groupingWindow;

  /// Show the other person's avatar next to their messages in direct
  /// rooms. Groups always show avatars. Defaults to false.
  final bool showAvatarsInDirect;

  /// Show the author's name above their messages in groups. Defaults to
  /// true.
  final bool showAuthorNamesInGroup;

  /// On a shared business profile, show the colleague's name above the
  /// messages they sent (`Message.sentBy`). Customers never see it: for
  /// them the message is from the business.
  final bool showSentBy;

  /// Swiping a message sideways starts a reply to it. Defaults to true.
  final bool swipeToReply;

  /// Show reactions under messages and the quick reaction row in the
  /// long-press sheet. Defaults to true.
  final bool enableReactions;

  /// Emojis of the quick reaction row, in order. Defaults to
  /// 👍 ❤️ 😂 😮 😢 🙏.
  final List<String> quickReactions;

  /// Mark the room read (`ChatSource.markRead`) when the newest messages
  /// are on screen. When false, call `ChatKit.repository.markRead`
  /// yourself. Defaults to true.
  final bool markReadWhenAtBottom;

  /// How long a message stays highlighted after a jump to it (a tapped
  /// reply quote). Defaults to 1.5 seconds.
  final Duration highlightDuration;

  /// Minimum gap between two "typing" notifications to the backend.
  /// Defaults to 3 seconds.
  final Duration typingThrottle;

  /// Idle time after which "stopped typing" is sent; also how long another
  /// member shows as typing without a new event. Defaults to 5 seconds.
  final Duration typingTimeout;

  /// Delay between the last keystroke in the inbox search and the search
  /// itself. Defaults to 350 ms.
  final Duration searchDebounce;

  /// Keep at most this many messages per room in the cache. Null keeps all.
  final int? maxCachedMessagesPerRoom;

  /// How long a resolved user stays fresh before the `ChatUserResolver` is
  /// asked again. Defaults to 12 hours.
  final Duration userCacheTtl;

  /// Reject attachments bigger than this. Null means no limit.
  final int? maxAttachmentBytes;

  /// Shorter voice recordings are discarded.
  final Duration minVoiceDuration;

  /// Size limit of the local media store; least recently used files go
  /// first. Null keeps everything.
  final int? maxMediaCacheBytes;

  /// Kinds downloaded as soon as they show. Others (video and files by
  /// default) download when tapped.
  final Set<AttachmentKind> autoDownload;

  /// A copy with the given fields replaced. Nullable fields
  /// ([maxCachedMessagesPerRoom], [maxAttachmentBytes],
  /// [maxMediaCacheBytes]) cannot be set back to null this way.
  ChatConfig copyWith({
    int? pageSize,
    int? roomsPageSize,
    int? preloadThreshold,
    AutoScrollPolicy? autoScrollPolicy,
    Duration? groupingWindow,
    bool? showAvatarsInDirect,
    bool? showAuthorNamesInGroup,
    bool? showSentBy,
    bool? swipeToReply,
    bool? enableReactions,
    List<String>? quickReactions,
    bool? markReadWhenAtBottom,
    Duration? highlightDuration,
    Duration? typingThrottle,
    Duration? typingTimeout,
    Duration? searchDebounce,
    int? maxCachedMessagesPerRoom,
    Duration? userCacheTtl,
    int? maxAttachmentBytes,
    Duration? minVoiceDuration,
    int? maxMediaCacheBytes,
    Set<AttachmentKind>? autoDownload,
  }) {
    return ChatConfig(
      pageSize: pageSize ?? this.pageSize,
      roomsPageSize: roomsPageSize ?? this.roomsPageSize,
      preloadThreshold: preloadThreshold ?? this.preloadThreshold,
      autoScrollPolicy: autoScrollPolicy ?? this.autoScrollPolicy,
      groupingWindow: groupingWindow ?? this.groupingWindow,
      showAvatarsInDirect: showAvatarsInDirect ?? this.showAvatarsInDirect,
      showAuthorNamesInGroup:
          showAuthorNamesInGroup ?? this.showAuthorNamesInGroup,
      showSentBy: showSentBy ?? this.showSentBy,
      swipeToReply: swipeToReply ?? this.swipeToReply,
      enableReactions: enableReactions ?? this.enableReactions,
      quickReactions: quickReactions ?? this.quickReactions,
      markReadWhenAtBottom: markReadWhenAtBottom ?? this.markReadWhenAtBottom,
      highlightDuration: highlightDuration ?? this.highlightDuration,
      typingThrottle: typingThrottle ?? this.typingThrottle,
      typingTimeout: typingTimeout ?? this.typingTimeout,
      searchDebounce: searchDebounce ?? this.searchDebounce,
      maxCachedMessagesPerRoom:
          maxCachedMessagesPerRoom ?? this.maxCachedMessagesPerRoom,
      userCacheTtl: userCacheTtl ?? this.userCacheTtl,
      maxAttachmentBytes: maxAttachmentBytes ?? this.maxAttachmentBytes,
      minVoiceDuration: minVoiceDuration ?? this.minVoiceDuration,
      maxMediaCacheBytes: maxMediaCacheBytes ?? this.maxMediaCacheBytes,
      autoDownload: autoDownload ?? this.autoDownload,
    );
  }
}
