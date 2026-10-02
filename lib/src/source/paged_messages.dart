import 'package:flutter_chat_pro/src/models/chat_page.dart';
import 'package:flutter_chat_pro/src/models/chat_user.dart';
import 'package:flutter_chat_pro/src/models/message.dart';
import 'package:flutter_chat_pro/src/models/message_cursor.dart';

/// Loads page [page] of a room, [size] messages per page, page `firstPage`
/// being the newest. Returns the raw JSON items.
typedef FetchMessagePage =
    Future<List<Object?>> Function(
      String roomId, {
      required int page,
      required int size,
    });

/// Builds a [Message] from one JSON item of a page.
typedef DecodeMessage =
    Message Function(Map<String, Object?> json, String roomId);

/// Serves `ChatSource.fetchMessages` from an API that pages by number or
/// offset (`?page=3&size=30`, `?offset=60&limit=30`) instead of by cursor.
///
/// ```dart
/// final paged = PagedMessages(
///   fetchPage: (roomId, {required page, required size}) async {
///     final res = await api.get('/rooms/$roomId/messages',
///         query: {'page': '$page', 'size': '$size'});
///     return res['data'] as List;
///   },
///   decode: (json, roomId) => Message.fromJson(json, roomId: roomId),
/// );
///
/// @override
/// Future<ChatPage<Message>> fetchMessages(String roomId,
///         {MessageCursor? before, MessageCursor? after, int limit = 30}) =>
///     paged.fetch(roomId, before: before, after: after, limit: limit);
/// ```
///
/// For an offset API, compute it in `fetchPage`:
/// `offset: (page - 1) * size`.
///
/// Pages must be newest first. New messages push older ones to later
/// pages, so items are filtered by cursor and deduplicated by id, never
/// trusted by position. Scrolling back resumes from the page where the
/// previous call stopped (read again in case deletions shifted it), so a
/// screen costs about two requests, not a walk from the newest page.
class PagedMessages {
  PagedMessages({
    required this.fetchPage,
    required this.decode,
    this.userOf,
    this.pageSize = 30,
    this.firstPage = 1,
    this.maxPages = 20,
  }) : assert(pageSize > 0, 'pageSize must be positive'),
       assert(maxPages > 0, 'maxPages must be positive');

  final FetchMessagePage fetchPage;
  final DecodeMessage decode;

  /// The sender embedded in a JSON item, returned in `ChatPage.users` so
  /// names show without a `ChatUserResolver`.
  final ChatUser? Function(Map<String, Object?> json)? userOf;

  /// Messages per page, sent as `size`. Keep it fixed: page numbers only
  /// line up while the size does not change.
  final int pageSize;

  /// Number of the newest page: 1, or 0 for zero-based APIs.
  final int firstPage;

  /// Requests one [fetch] may make. A call that reaches it returns what it
  /// found with `hasMore: true`.
  final int maxPages;

  final Map<String, ({int page, MessageCursor cursor})> _resume = {};

  /// One page in the `ChatSource.fetchMessages` sense: the latest [limit]
  /// messages, the [limit] just older than [before], or the [limit] just
  /// newer than [after], newest first.
  Future<ChatPage<Message>> fetch(
    String roomId, {
    MessageCursor? before,
    MessageCursor? after,
    int limit = 30,
  }) async {
    final hint = _resume[roomId];
    var page = before != null && after == null && hint?.cursor == before
        ? hint!.page
        : firstPage;

    final found = <String, Message>{};
    final pageOf = <String, int>{};
    final users = <String, ChatUser>{};
    var reachedEnd = false;
    var reachedAfter = false;
    var checkedStart = page == firstPage;

    for (var requests = 0; requests < maxPages; requests++) {
      final raw = await fetchPage(roomId, page: page, size: pageSize);
      final jsons = raw.cast<Map<String, Object?>>();
      final items = [for (final json in jsons) decode(json, roomId)]
        ..sort((a, b) => b.cursor.compareTo(a.cursor));
      final sender = userOf;
      if (sender != null) {
        for (final json in jsons) {
          final user = sender(json);
          if (user != null) users[user.id] = user;
        }
      }

      if (!checkedStart) {
        // Deletions since the last call move messages to earlier pages:
        // step back until the page starts at or above the cursor.
        final top = items.firstOrNull?.cursor;
        if (top == null || top.isBefore(before!)) {
          page--;
          checkedStart = page == firstPage;
          continue;
        }
        checkedStart = true;
      }

      for (final m in items) {
        if (after != null && !m.cursor.isAfter(after)) {
          reachedAfter = true;
          continue;
        }
        if (before != null && !m.cursor.isBefore(before)) continue;
        found[m.id] = m;
        pageOf[m.id] ??= page;
      }
      if (raw.length < pageSize) {
        reachedEnd = true;
        break;
      }
      if (reachedAfter) break;
      if (after == null && found.length >= limit) break;
      page++;
    }

    final sorted = found.values.toList()
      ..sort((a, b) => b.cursor.compareTo(a.cursor));
    final List<Message> result;
    final bool hasMore;
    if (after != null) {
      result = sorted.length > limit
          ? sorted.sublist(sorted.length - limit)
          : sorted;
      hasMore = sorted.length > limit || !(reachedAfter || reachedEnd);
    } else {
      result = sorted.take(limit).toList();
      hasMore = sorted.length > limit || !reachedEnd;
      final last = result.lastOrNull;
      if (last != null) {
        _resume[roomId] = (page: pageOf[last.id]!, cursor: last.cursor);
      }
    }
    final authors = {for (final m in result) m.authorId};
    return ChatPage(
      items: result,
      hasMore: hasMore,
      users: [
        for (final user in users.values)
          if (authors.contains(user.id)) user,
      ],
    );
  }
}
