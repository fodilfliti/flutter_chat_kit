import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/controllers/audio_player_hub.dart';
import 'package:flutter_chat_pro/src/controllers/chat_kit_scope.dart';
import 'package:flutter_chat_pro/src/media/chat_media_store.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';

/// Gives media widgets (`ChatImage`, the audio and video views) the media
/// store and the audio player. `ChatMessageList` provides the kit's; without
/// a scope they fall back to `ChatKitScope`, else load URLs directly.
class ChatMediaScope extends InheritedWidget {
  const ChatMediaScope({
    required super.child,
    this.store,
    this.audio,
    this.autoDownload = const {AttachmentKind.image, AttachmentKind.audio},
    super.key,
  });

  final ChatMediaStore? store;
  final AudioPlayerHub? audio;

  /// Kinds loaded as soon as they show; others wait for a tap.
  final Set<AttachmentKind> autoDownload;

  /// The nearest scope, else one built from the kit in `ChatKitScope`,
  /// else an empty one.
  // The `of(context)` lookup is the Flutter convention for inherited widgets.
  // ignore: prefer_constructors_over_static_methods
  static ChatMediaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChatMediaScope>();
    if (scope != null) return scope;
    final kit = ChatKitScope.maybeOf(context);
    return ChatMediaScope(
      store: kit?.media,
      audio: kit?.audio,
      autoDownload: kit?.config.autoDownload ?? const {},
      child: const SizedBox.shrink(),
    );
  }

  @override
  bool updateShouldNotify(ChatMediaScope oldWidget) =>
      oldWidget.store != store ||
      oldWidget.audio != audio ||
      oldWidget.autoDownload != autoDownload;
}
