import 'package:flutter_chat_kit/src/models/chat_user.dart';

/// Loads user profiles by id. The kit batches ids and caches the results.
abstract interface class ChatUserResolver {
  /// Returns the users it found; missing ids are simply absent.
  Future<List<ChatUser>> resolve(Set<String> ids);
}
