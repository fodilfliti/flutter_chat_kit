import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/models/message.dart';

/// One-line summary of [message] for reply previews and the inbox.
String messageSnippet(Message message, ChatStrings strings) {
  if (message.isDeleted) return strings.messageDeleted;
  String orLabel(String? text, String label) =>
      text == null || text.trim().isEmpty ? label : text;
  return switch (message) {
    TextMessage(:final text) => text,
    ImageMessage(:final caption, :final images) => orLabel(
      caption,
      strings.photos(images.length),
    ),
    VideoMessage(:final caption) => orLabel(caption, strings.video),
    AudioMessage() => strings.voice,
    FileMessage(:final file) => orLabel(file.name, strings.file),
    SystemMessage(:final code, :final args) => strings.system(code, args),
    CustomMessage() => strings.unsupportedMessage,
  };
}

/// The text a "copy" action puts on the clipboard, or null when the
/// message has none.
String? copyableText(Message message) {
  if (message.isDeleted) return null;
  final text = switch (message) {
    TextMessage(:final text) => text,
    ImageMessage(:final caption) => caption,
    VideoMessage(:final caption) => caption,
    _ => null,
  };
  return text == null || text.trim().isEmpty ? null : text;
}
