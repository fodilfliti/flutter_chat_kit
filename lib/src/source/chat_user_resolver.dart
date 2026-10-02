import 'package:flutter_chat_pro/src/models/chat_user.dart';

/// Loads user profiles by id. The kit batches ids and caches the results.
///
/// Pass it as `ChatKit.users`. Optional: backends that send names and
/// avatars with their pages (`ChatPage.users`) or events (`UsersChanged`)
/// do not need one.
abstract interface class ChatUserResolver {
  /// Returns the users it found; missing ids are simply absent.
  ///
  /// Called for ids the screens show (room peers, message authors) that
  /// are not cached or are older than `ChatConfig.userCacheTtl`. Lookups
  /// within a few milliseconds share one call, and the screens update when
  /// the users arrive.
  ///
  /// Throw an `AppFailure` on error; the kit then keeps what it has cached
  /// and asks again later.
  ///
  /// ```dart
  /// @override
  /// Future<List<ChatUser>> resolve(Set<String> ids) async {
  ///   final res = await api.get('/users', query: {'ids': ids.join(',')});
  ///   return [for (final u in res['items'] as List) ChatUser.fromJson(u)];
  /// }
  /// ```
  Future<List<ChatUser>> resolve(Set<String> ids);
}
