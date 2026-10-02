import 'package:flutter/widgets.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/custom/custom_messages.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';

final _cache = Expando<ChatStrings>();

/// The chat texts in the current app language. Reading it from `context.t`
/// rebuilds the caller when the language changes.
ChatStrings chatStringsOf(BuildContext context) {
  final t = context.t;
  return _cache[t] ??= buildChatStrings(t);
}

/// Every [ChatStrings] field from the slang translations, so no text of the
/// chat stays in English.
ChatStrings buildChatStrings(Translations t) {
  final c = t.chat;
  return ChatStrings(
    typeMessage: c.typeMessage,
    today: c.today,
    yesterday: c.yesterday,
    newMessages: c.newMessages,
    reply: c.reply,
    copy: c.copy,
    copied: c.copied,
    edit: c.edit,
    delete: c.delete,
    retry: c.retry,
    cancel: c.cancel,
    send: c.send,
    failedToSend: c.failedToSend,
    messageDeleted: c.messageDeleted,
    unsupportedMessage: c.unsupportedMessage,
    edited: c.edited,
    editing: c.editing,
    you: c.you,
    online: c.online,
    slideToCancel: c.slideToCancel,
    searchChats: c.searchChats,
    noChats: c.noChats,
    noMessages: c.noMessages,
    loadFailed: c.loadFailed,
    startOfConversation: c.startOfConversation,
    scrollToBottom: c.scrollToBottom,
    photo: c.photo,
    video: c.video,
    voice: c.voice,
    file: c.file,
    camera: c.camera,
    gallery: c.gallery,
    attachmentTooLarge: c.attachmentTooLarge,
    fileUnavailable: c.fileUnavailable,
    compressing: c.compressing,
    readMore: c.readMore,
    readLess: c.readLess,
    replyUnavailable: c.replyUnavailable,
    statusPending: c.statusPending,
    statusSent: c.statusSent,
    statusDelivered: c.statusDelivered,
    statusSeen: c.statusSeen,
    messageOptions: c.messageOptions,
    save: c.save,
    saved: c.saved,
    download: c.download,
    downloadFailed: c.downloadFailed,
    play: c.play,
    pause: c.pause,
    close: c.close,
    attach: c.attach,
    removeAttachment: c.removeAttachment,
    recordVoice: c.recordVoice,
    holdToRecord: c.holdToRecord,
    microphoneDenied: c.microphoneDenied,
    slideUpToLock: c.slideUpToLock,
    stopRecording: c.stopRecording,
    back: c.back,
    forward: c.forward,
    select: c.select,
    pin: c.pin,
    unpin: c.unpin,
    mute: c.mute,
    unmute: c.unmute,
    clearSearch: c.clearSearch,
    noResults: c.noResults,
    loadChatsFailed: c.loadChatsFailed,
    switchProfile: c.switchProfile,
    businessProfile: c.businessProfile,
    typing: (names) => switch (names) {
      [] => '',
      [final name] => c.typingOne(name: name),
      [final a, final b] => c.typingTwo(a: a, b: b),
      _ => c.typingMany(n: names.length),
    },
    system: (code, args) => switch ((code, args['name'], args['title'])) {
      ('room_created', final String name, final String title) =>
        c.system.roomCreated(name: name, title: title),
      _ => ChatStrings.defaultSystem(code, args),
    },
    lastSeen: (when) => c.lastSeen(when: when),
    photos: (count) => c.photos(n: count),
    reaction: (emoji, count) => c.reaction(n: count, emoji: emoji),
    reactWith: (emoji) => c.reactWith(emoji: emoji),
    playbackSpeed: (speed) => c.playbackSpeed(
      speed: speed == speed.roundToDouble()
          ? speed.toStringAsFixed(0)
          : '$speed',
    ),
    moreMedia: (count) => c.moreMedia(n: count),
    mediaPosition: (index, total) =>
        c.mediaPosition(index: index, total: total),
    members: (count) => c.members(n: count),
    selectedCount: (count) => c.selectedCount(n: count),
    previewWithAuthor: (author, text) =>
        c.previewWithAuthor(author: author, text: text),
    unreadCount: (count) => c.unreadCount(n: count),
    customPreview: (type, data) => customPreview(t, type, data),
  );
}
