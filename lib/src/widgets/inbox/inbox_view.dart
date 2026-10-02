import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/builders/inbox_builders.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/inbox_controller.dart';
import 'package:flutter_chat_kit/src/models/chat_room.dart';
import 'package:flutter_chat_kit/src/widgets/common/chat_style.dart';
import 'package:flutter_chat_kit/src/widgets/inbox/inbox_search_bar.dart';
import 'package:flutter_chat_kit/src/widgets/inbox/room_swipe_actions.dart';
import 'package:flutter_chat_kit/src/widgets/inbox/room_tile.dart';

/// Builds the page of a room opened from the inbox.
typedef ChatRoomPageBuilder =
    Widget Function(BuildContext context, ChatRoom room);

/// The room list: search bar, optional [header], [RoomTile]s with pin and
/// mute swipe actions, pull to refresh, and the next page loaded near the
/// end.
///
/// Tapping a room pushes the page from [roomBuilder], which keeps the
/// surrounding `ChatStyle`, or calls [onRoomTap] for your own navigation
/// (a router package, a split view). Long press shows the swipe actions in
/// a sheet unless [onRoomLongPress] is set.
///
/// ```dart
/// InboxView(
///   controller: inbox, // kit.inbox(), disposed by the caller
///   roomBuilder: (context, room) => RoomPage(kit: kit, roomId: room.id),
/// )
/// ```
class InboxView extends StatefulWidget {
  /// A room list for [controller]. Pass [roomBuilder] or [onRoomTap]
  /// (asserted).
  const InboxView({
    required this.controller,
    this.onRoomTap,
    this.roomBuilder,
    this.onRoomLongPress,
    this.builders = const InboxBuilders(),
    this.showSearch = true,
    this.header,
    this.theme,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.loadMoreThreshold = 400,
    super.key,
  }) : assert(
         onRoomTap != null || roomBuilder != null,
         'Pass roomBuilder (or onRoomTap for your own navigation).',
       );

  /// The rooms shown, from `ChatKit.inbox`. The caller disposes it.
  final InboxController controller;

  /// Your own navigation; wins over [roomBuilder]. Use
  /// `ChatStyle.carry(context)` to keep the style on the page you open.
  final ValueChanged<ChatRoom>? onRoomTap;

  /// Pushes this page with `ChatStyle.push`, so the room keeps the style
  /// of the list.
  final ChatRoomPageBuilder? roomBuilder;

  /// Called with the long-pressed room. Null: a sheet shows the pin and
  /// mute actions (or those from `InboxBuilders.swipeActions`).
  final ValueChanged<ChatRoom>? onRoomLongPress;

  /// Replaces or wraps tiles, empty and error states, and swipe actions.
  final InboxBuilders builders;

  /// Shows the search bar above the list, which filters by room title and
  /// member name. Defaults to true.
  final bool showSearch;

  /// Shown below the search bar, such as stories or a banner.
  final Widget? header;

  /// Applied to this list only; defaults to the ambient `ChatTheme`. The
  /// scale of a surrounding `ChatStyle` still applies.
  final ChatTheme? theme;

  /// Every visible text (English by default); override for translations.
  final ChatStrings strings;

  /// Times and dates shown on the tiles.
  final ChatFormatters formatters;

  /// Distance from the end, in pixels, at which the next page loads.
  /// Defaults to 400.
  final double loadMoreThreshold;

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  final _scroll = ScrollController();
  bool _checkScheduled = false;

  InboxController get _c => widget.controller;

  ChatStrings get _strings => widget.strings;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.extentAfter < widget.loadMoreThreshold) {
      _loadMore();
    }
    return false;
  }

  void _loadMore() {
    if (_c.hasMore && !_c.isLoading) unawaited(_c.loadMore());
  }

  /// Keeps loading while the rooms do not fill the viewport, since nothing
  /// can scroll then (also when a filtered list is still empty because the
  /// backend ignored the filter). Stops after a failure so it never retries
  /// in a loop.
  void _scheduleFillCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_scroll.hasClients || _c.failure != null) return;
      if (_c.isLoading || _c.isLoadingMore) return;
      if (_scroll.position.extentAfter < widget.loadMoreThreshold) {
        _loadMore();
      }
    });
  }

  RoomContext _contextOf(ChatRoom room, int index) {
    final peerId = room.otherUserId(_c.currentUserId);
    final authorId = room.lastMessage?.authorId;
    final sentBy = room.lastMessage?.sentBy;
    return RoomContext(
      room: room,
      currentUserId: _c.currentUserId,
      index: index,
      agentId: _c.kit.agentId,
      peer: _c.peerOf(room),
      lastMessageAuthor: authorId == null ? null : _c.users[authorId],
      lastMessageSender: sentBy == null ? null : _c.users[sentBy],
      presence: peerId == null ? null : _c.presenceOf(peerId),
      typingNames: _c.typingNames(room),
    );
  }

  List<RoomAction> _actionsOf(BuildContext context, RoomContext room) {
    final r = room.room;
    final defaults = [
      RoomAction(
        id: 'pin',
        label: r.pinned ? _strings.unpin : _strings.pin,
        icon: r.pinned ? Icons.push_pin_outlined : Icons.push_pin,
        onTap: () => _c.setPinned(r.id, pinned: !r.pinned),
      ),
      RoomAction(
        id: 'mute',
        label: r.muted ? _strings.unmute : _strings.mute,
        icon: r.muted ? Icons.volume_up : Icons.volume_off,
        onTap: () => _c.setMuted(r.id, muted: !r.muted),
      ),
    ];
    return widget.builders.swipeActions?.call(context, room, defaults) ??
        defaults;
  }

  Future<void> _showActions(List<RoomAction> actions) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  textColor: action.isDestructive
                      ? Theme.of(sheet).colorScheme.error
                      : null,
                  iconColor: action.isDestructive
                      ? Theme.of(sheet).colorScheme.error
                      : null,
                  onTap: () {
                    Navigator.pop(sheet);
                    unawaited(Future.sync(action.onTap));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoom(ChatRoom room) {
    if (widget.onRoomTap case final onTap?) return onTap(room);
    final builder = widget.roomBuilder;
    if (builder == null) return;
    unawaited(
      ChatStyle.push<void>(context, (context) => builder(context, room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = widget.theme;
    final child = ListenableBuilder(listenable: _c, builder: _build);
    if (chatTheme == null) return child;
    final base = Theme.of(context);
    final scale = ChatStyle.scaleOf(context);
    final scaled = scale.isNone
        ? chatTheme
        : chatTheme.scaled(scale.size, textFactor: scale.text);
    return Theme(
      data: base.copyWith(extensions: [...base.extensions.values, scaled]),
      child: child,
    );
  }

  Widget _build(BuildContext context, Widget? _) {
    final builders = widget.builders;
    final rooms = _c.rooms;

    Widget? search;
    if (widget.showSearch) {
      search = InboxSearchBar(
        onChanged: _c.search,
        initialQuery: _c.query,
        strings: _strings,
      );
      if (builders.searchBarBuilder case final build?) {
        search = build(context, search);
      }
    }

    if (_c.hasMore) _scheduleFillCheck();
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _c.refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (search != null) SliverToBoxAdapter(child: search),
            if (widget.header case final header?)
              SliverToBoxAdapter(child: header),
            if (rooms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(context),
              )
            else ...[
              SliverList.builder(
                itemCount: rooms.length,
                itemBuilder: (context, index) => _tile(context, rooms, index),
              ),
              if (_c.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, List<ChatRoom> rooms, int index) {
    final room = rooms[index];
    final roomContext = _contextOf(room, index);
    final actions = _actionsOf(context, roomContext);
    final onLongPress = widget.onRoomLongPress;
    return RoomSwipeActions(
      key: ValueKey(room.id),
      actions: actions,
      child: RoomTile(
        room: roomContext,
        users: _c.users,
        builders: widget.builders,
        strings: _strings,
        formatters: widget.formatters,
        onTap: () => _openRoom(room),
        onLongPress: onLongPress != null
            ? () => onLongPress(room)
            : actions.isEmpty
            ? null
            : () => unawaited(_showActions(actions)),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final builders = widget.builders;
    final theme = ChatTheme.of(context);
    final failure = _c.failure;
    final fetching = _c.isLoading || _c.isLoadingMore || _c.hasMore;
    if (!_c.hasLoadedCache || (fetching && failure == null)) {
      const loading = Center(child: CircularProgressIndicator());
      return builders.loadingBuilder?.call(context, loading) ?? loading;
    }
    if (failure != null) {
      final retry = _c.refresh;
      final error = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_strings.loadChatsFailed, style: theme.captionStyle),
            SizedBox(height: theme.size(8)),
            TextButton(
              onPressed: () => unawaited(retry()),
              child: Text(_strings.retry),
            ),
          ],
        ),
      );
      return builders.errorBuilder?.call(
            context,
            failure,
            () => unawaited(retry()),
            error,
          ) ??
          error;
    }
    final empty = Center(
      child: Padding(
        padding: EdgeInsets.all(theme.size(24)),
        child: Text(
          _c.query.isEmpty ? _strings.noChats : _strings.noResults,
          style: theme.captionStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return builders.emptyBuilder?.call(context, empty) ?? empty;
  }
}
