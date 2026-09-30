import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';

/// When the message list scrolls to a newly arrived message.
enum AutoScrollPolicy {
  always,

  /// Scroll for the user's own messages, or when already at the bottom.
  /// Otherwise the "new messages" badge counts up.
  whenMineOrAtBottom,
  never,
}

/// Behaviour settings shared by the kit's controllers and widgets.
@immutable
class ChatConfig {
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

  /// Messages per fetch.
  final int pageSize;
  final int roomsPageSize;

  /// Load older messages when this many items remain above the viewport.
  final int preloadThreshold;
  final AutoScrollPolicy autoScrollPolicy;

  /// Consecutive messages by one author within this window are grouped.
  final Duration groupingWindow;
  final bool showAvatarsInDirect;
  final bool showAuthorNamesInGroup;

  /// On a shared business profile, show the colleague's name above the
  /// messages they sent (`Message.sentBy`). Customers never see it: for
  /// them the message is from the business.
  final bool showSentBy;
  final bool swipeToReply;
  final bool enableReactions;
  final List<String> quickReactions;
  final bool markReadWhenAtBottom;
  final Duration highlightDuration;

  /// Minimum gap between two "typing" notifications to the backend.
  final Duration typingThrottle;

  /// Idle time after which "stopped typing" is sent.
  final Duration typingTimeout;
  final Duration searchDebounce;

  /// Keep at most this many messages per room in the cache. Null keeps all.
  final int? maxCachedMessagesPerRoom;
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
