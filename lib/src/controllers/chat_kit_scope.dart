import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/controllers/chat_kit.dart';

/// Provides a [ChatKit] to the widget tree. The scope does not own the kit;
/// whoever created it closes it.
class ChatKitScope extends InheritedNotifier<ChatKit> {
  const ChatKitScope({required ChatKit kit, required super.child, super.key})
    : super(notifier: kit);

  static ChatKit? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatKitScope>()?.notifier;
  }

  static ChatKit of(BuildContext context) {
    final kit = maybeOf(context);
    if (kit == null) {
      throw FlutterError(
        'ChatKitScope.of() called with a context that has no ChatKitScope.\n'
        'Wrap your chat screens in ChatKitScope(kit: kit, child: ...).',
      );
    }
    return kit;
  }
}

extension ChatKitContext on BuildContext {
  ChatKit get chatKit => ChatKitScope.of(this);
}
