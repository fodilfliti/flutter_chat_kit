import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter_chat_kit/src/builders/chat_builders.dart';
import 'package:flutter_chat_kit/src/builders/message_context.dart';
import 'package:flutter_chat_kit/src/config/chat_config.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_kit/src/models/chat_user.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/models/message_cursor.dart';
import 'package:flutter_chat_kit/src/models/typing.dart';
import 'package:flutter_chat_kit/src/widgets/common/chat_avatar.dart';
import 'package:flutter_chat_kit/src/widgets/room/date_separator.dart';
import 'package:flutter_chat_kit/src/widgets/room/floating_date_header.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_grouping.dart';
import 'package:flutter_chat_kit/src/widgets/room/message_row.dart';
import 'package:flutter_chat_kit/src/widgets/room/scroll_to_bottom_button.dart';
import 'package:flutter_chat_kit/src/widgets/room/typing_indicator.dart';
import 'package:flutter_chat_kit/src/widgets/room/unread_divider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// Renders the content of one message (the bubble and what is inside).
typedef MessageContentBuilder =
    Widget Function(BuildContext context, MessageContext message);

typedef MessageCallback = void Function(MessageContext message);

/// The scrolling list of a room: newest message at the bottom, older pages
/// loaded as the user scrolls up without moving what is on screen, day
/// separators, the unread divider, the typing indicator, a
/// scroll-to-bottom button with a new-message badge, and jump to any
/// message ([ChatMessageListState.jumpToMessage]).
///
/// It reads everything from [controller] and reports the viewport back
/// through `ChatRoomController.onViewportChanged`.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    required this.controller,
    this.builders = const ChatBuilders(),
    this.config,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    this.onMessageTap,
    this.onMessageLongPress,
    this.onAvatarTap,
    this.padding,
    this.contentBuilder,
    super.key,
  });

  final ChatRoomController controller;
  final ChatBuilders builders;

  /// Defaults to the kit's config.
  final ChatConfig? config;
  final ChatStrings strings;
  final ChatFormatters formatters;
  final MessageCallback? onMessageTap;
  final MessageCallback? onMessageLongPress;

  /// Called with the author's user id.
  final ValueChanged<String>? onAvatarTap;

  /// Defaults to `ChatTheme.listPadding`.
  final EdgeInsets? padding;

  /// Renders message content. Defaults to a plain bubble.
  final MessageContentBuilder? contentBuilder;

  /// The nearest list state, for example to jump from a reply preview.
  static ChatMessageListState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ChatMessageListState>();

  @override
  State<ChatMessageList> createState() => ChatMessageListState();
}

/// Layout: a reversed `CustomScrollView` whose `center` is the sliver of
/// messages up to an anchor (the newest message when the list was last
/// reset), growing upwards. Messages newer than the anchor go in a sliver
/// before the center, which grows downwards. New and newer-page messages
/// therefore extend the scroll range below the viewport instead of pushing
/// the visible messages, and older pages extend it above.
class ChatMessageListState extends State<ChatMessageList> {
  static const _bottomSlop = 48.0;
  static const _centerKey = ValueKey<Symbol>(#center);
  static const _noProgress = _NoProgress();

  final _scroll = ScrollController();
  final _olderList = ListController();
  final _newerList = ListController();
  final _showButton = ValueNotifier<bool>(false);
  final _header = ValueNotifier<String?>(null);
  final _headerVisible = ValueNotifier<bool>(false);
  Timer? _headerTimer;

  /// All rows, newest first.
  List<ChatListItem> _items = const [];

  /// Rows up to the anchor, newest first (index 0 next to the center).
  List<ChatListItem> _older = const [];

  /// Rows after the anchor, oldest first (index 0 next to the center).
  List<ChatListItem> _newer = const [];
  Map<Object, int> _olderIndex = const {};
  Map<Object, int> _newerIndex = const {};
  MessageCursor? _anchor;
  List<Message>? _itemsOf;
  MessageCursor? _dividerOf;
  bool _startOf = false;
  Message? _newest;
  bool _typingShown = false;

  /// Contexts of the built message rows, by local id.
  final _rows = <String, BuildContext>{};

  bool _atBottom = true;
  bool _needsBottom = true;
  bool _checkScheduled = false;
  Set<String> _selected = const {};

  ChatRoomController get _controller => widget.controller;

  ChatConfig get _config => widget.config ?? _controller.kit.config;

  /// Whether the scroll-to-bottom button shows.
  @visibleForTesting
  ValueListenable<bool> get showsScrollToBottom => _showButton;

  @override
  void initState() {
    super.initState();
    _attach(_controller);
    _syncItems(initial: true);
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, _controller)) {
      _detach(oldWidget.controller);
      _attach(_controller);
      _itemsOf = null;
      _newest = null;
      _anchor = null;
      _syncItems(initial: true);
    }
  }

  @override
  void dispose() {
    _detach(_controller);
    _headerTimer?.cancel();
    _scroll.dispose();
    _olderList.dispose();
    _newerList.dispose();
    _showButton.dispose();
    _header.dispose();
    _headerVisible.dispose();
    super.dispose();
  }

  void _attach(ChatRoomController controller) {
    controller.addListener(_onController);
    controller.highlightedId.addListener(_onHighlight);
  }

  void _detach(ChatRoomController controller) {
    controller.removeListener(_onController);
    controller.highlightedId.removeListener(_onHighlight);
  }

  // ------------------------------------------------------------ public API

  /// Scrolls to [id] (id or local id), loading its part of the history
  /// first when needed, and highlights it. Returns false when the message
  /// can't be found.
  Future<bool> jumpToMessage(String id) async {
    final c = _controller;
    final wasLoaded = c.messages.any((m) => m.matches(id));
    final index = await c.jumpToMessage(id);
    if (index == null || !mounted) return false;
    // A new slice replaced the messages: start a fresh layout around it.
    if (!wasLoaded) _resetAnchor();
    await _endOfFrame();
    if (!mounted || !_scroll.hasClients) return false;
    final message = c.messages.firstWhere(
      (m) => m.matches(id),
      orElse: () => c.messages[index],
    );
    return await _reveal(message.localId);
  }

  /// Centers the row of [localId]: straight to it when it is built,
  /// otherwise to its estimated offset first.
  Future<bool> _reveal(String localId) async {
    if (await _ensureVisible(localId)) return true;
    final target = _estimatedOffset(localId);
    if (target == null || !_scroll.hasClients) return false;
    final position = _scroll.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final distance = (clamped - position.pixels).abs();
    await position.animateTo(
      clamped,
      duration: Duration(
        milliseconds: (200 + distance / 8).clamp(200, 600).round(),
      ),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return false;
    await _endOfFrame();
    if (!mounted) return false;
    await _ensureVisible(localId);
    return true;
  }

  Future<bool> _ensureVisible(String localId) async {
    final row = _rows[localId];
    if (row == null || !row.mounted) return false;
    await Scrollable.ensureVisible(
      row,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  /// Scroll offset that centers the row, from measured or estimated row
  /// extents. The older sliver starts at offset 0 and grows upwards; the
  /// newer one ends at 0 and grows downwards.
  double? _estimatedOffset(String localId) {
    double centerIn(ListController list, int index) {
      var before = 0.0;
      for (var i = 0; i < index; i++) {
        before += list.extentForIndex(i).$1;
      }
      return before + list.extentForIndex(index).$1 / 2;
    }

    final viewport = _scroll.position.viewportDimension;
    final older = _olderIndex[localId];
    if (older != null && _olderList.isAttached) {
      return centerIn(_olderList, older) - viewport / 2;
    }
    final newer = _newerIndex[localId];
    if (newer != null && _newerList.isAttached) {
      return -centerIn(_newerList, newer) - viewport / 2;
    }
    return null;
  }

  /// Returns to the newest messages (leaving a detached slice first).
  Future<void> scrollToBottom() async {
    if (_controller.isDetached) {
      await _controller.returnToLatest();
      if (!mounted) return;
      _resetAnchor();
      await _endOfFrame();
      if (!mounted) return;
    }
    _animateToBottom();
  }

  // ------------------------------------------------------------ controller

  void _onController() {
    _syncItems();
    _scheduleViewportCheck();
    setState(() {});
  }

  void _onHighlight() => setState(() {});

  /// Rebuilds the rows only when the messages, the divider or the start of
  /// history changed, and follows new messages per the auto-scroll policy.
  void _syncItems({bool initial = false}) {
    final c = _controller;
    final typing = c.typingUserIds.isNotEmpty;
    if (typing && !_typingShown && _atBottom && !initial) {
      _afterFrame(_animateToBottom);
    }
    _typingShown = typing;

    final messages = c.messages;
    final divider = c.unreadDividerCursor;
    final start = !c.hasMoreOlder;
    if (identical(messages, _itemsOf) &&
        divider == _dividerOf &&
        start == _startOf) {
      return;
    }
    _itemsOf = messages;
    _dividerOf = divider;
    _startOf = start;
    _items = buildChatListItems(
      messages,
      groupingWindow: _config.groupingWindow,
      unreadDividerCursor: divider,
      isStartOfHistory: start,
    );
    final newest = messages.isEmpty ? null : messages.first;
    _anchor ??= newest?.cursor;
    _split();

    final previous = _newest;
    _newest = newest;
    if (initial || previous == null || newest == null) return;
    if (newest.localId == previous.localId ||
        !newest.cursor.isAfter(previous.cursor) ||
        c.isDetached) {
      return;
    }
    final follow = switch (_config.autoScrollPolicy) {
      AutoScrollPolicy.always => true,
      AutoScrollPolicy.whenMineOrAtBottom =>
        newest.authorId == c.currentUserId || _atBottom,
      AutoScrollPolicy.never => false,
    };
    if (follow) _afterFrame(_animateToBottom);
  }

  /// Splits [_items] at [_anchor] into the two slivers.
  void _split() {
    final anchor = _anchor;
    var split = 0;
    if (anchor != null) {
      split = _items.indexWhere(
        (item) =>
            item is MessageListItem && !item.message.cursor.isAfter(anchor),
      );
      if (split < 0) split = _items.length;
    }
    _older = _items.sublist(split);
    _newer = _items.sublist(0, split).reversed.toList();
    _olderIndex = {for (var i = 0; i < _older.length; i++) _older[i].key: i};
    _newerIndex = {for (var i = 0; i < _newer.length; i++) _newer[i].key: i};
  }

  /// Moves the anchor to the newest message and the view to the bottom.
  /// Used when the messages were replaced (a jump, back to latest), so the
  /// layout starts from a single sliver again.
  void _resetAnchor() {
    _anchor = _controller.messages.isEmpty
        ? null
        : _controller.messages.first.cursor;
    _split();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _needsBottom = true;
    setState(() {});
  }

  // --------------------------------------------------------------- scroll

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      _headerTimer?.cancel();
      if (!_atBottom) _headerVisible.value = true;
    } else if (notification is ScrollEndNotification) {
      _headerTimer?.cancel();
      _headerTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _headerVisible.value = false;
      });
    }
    _scheduleViewportCheck();
    return false;
  }

  /// At most one viewport check per frame.
  void _scheduleViewportCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    _afterFrame(() {
      _checkScheduled = false;
      _checkViewport();
    });
  }

  void _checkViewport() {
    if (!_scroll.hasClients) return;
    final c = _controller;
    final position = _scroll.position;
    final atBottom = position.pixels <= position.minScrollExtent + _bottomSlop;
    if (atBottom != _atBottom) {
      _atBottom = atBottom;
      if (atBottom) _headerVisible.value = false;
      c.onViewportChanged(atBottom: atBottom);
    }
    _showButton.value = !atBottom || c.isDetached;

    final range = _visibleRange();
    if (range == null) return;
    final (first, last) = range;
    final threshold = _config.preloadThreshold;
    if (c.hasMoreOlder &&
        !c.isLoadingOlder &&
        last >= _items.length - 1 - threshold) {
      unawaited(c.loadOlder());
    }
    if (c.hasMoreNewer && !c.isLoadingNewer && first <= threshold) {
      unawaited(c.loadNewer());
    }
    _header.value = _headerLabel(first, last);
  }

  /// Visible rows as indices into [_items] (0 = newest).
  (int, int)? _visibleRange() {
    int? low;
    int? high;
    void add(int index) {
      low = low == null ? index : math.min(low!, index);
      high = high == null ? index : math.max(high!, index);
    }

    final n = _newer.length;
    if (_olderList.isAttached) {
      if (_olderList.visibleRange case (final a, final b)) {
        add(n + a);
        add(n + b);
      }
    }
    if (_newerList.isAttached) {
      if (_newerList.visibleRange case (final a, final b)) {
        add(n - 1 - a);
        add(n - 1 - b);
      }
    }
    final (l, h) = (low, high);
    return l == null || h == null ? null : (l, h);
  }

  /// The day of the topmost visible message.
  String? _headerLabel(int first, int last) {
    for (var i = math.min(last, _items.length - 1); i >= first; i--) {
      final item = _items[i];
      if (item is MessageListItem) {
        return widget.formatters.formatDateSeparator(
          item.message.createdAt,
          widget.strings,
          now: _controller.kit.clock(),
        );
      }
    }
    return null;
  }

  void _animateToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final bottom = position.minScrollExtent;
    if (position.pixels <= bottom) return;
    // Far away: jump most of the way so the animation stays short.
    if (position.pixels - bottom > position.viewportDimension * 3) {
      position.jumpTo(bottom + position.viewportDimension);
    }
    unawaited(
      position
          .animateTo(
            bottom,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          )
          // Rows measured during the animation can move the bottom.
          .then((_) => _jumpToBottom()),
    );
  }

  void _jumpToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels != position.minScrollExtent) {
      position.jumpTo(position.minScrollExtent);
    }
  }

  void _afterFrame(VoidCallback callback) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) callback();
      })
      ..ensureVisualUpdate();
  }

  Future<void> _endOfFrame() {
    final done = Completer<void>();
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => done.complete())
      ..ensureVisualUpdate();
    return done.future;
  }

  // ---------------------------------------------------------------- items

  static int? Function(Key key) _finder(Map<Object, int> index) =>
      (key) => key is ValueKey<Object> ? index[key.value] : null;

  Widget _sliver(
    List<ChatListItem> items,
    Map<Object, int> index,
    ListController controller,
    EdgeInsets padding,
    double maxWidth, {
    Key? key,
    bool delayCacheArea = true,
  }) {
    return SliverPadding(
      key: key,
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      sliver: SuperSliverList(
        listController: controller,
        delayPopulatingCacheArea: delayCacheArea,
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              i < items.length ? _buildItem(context, items[i], maxWidth) : null,
          childCount: items.length,
          findChildIndexCallback: _finder(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final builders = widget.builders;
    final theme = ChatTheme.of(context);

    if (!c.hasLoadedCache || (c.messages.isEmpty && c.isSyncing)) {
      const child = Center(child: CircularProgressIndicator.adaptive());
      return builders.loadingBuilder?.call(context, child) ?? child;
    }
    if (c.messages.isEmpty &&
        !c.hasMoreOlder &&
        c.typingUserIds.isEmpty &&
        !c.isLoadingOlder) {
      final child = Center(
        child: Text(widget.strings.noMessages, style: theme.systemMessageStyle),
      );
      return builders.emptyBuilder?.call(context, child) ?? child;
    }

    _selected = c.selectedIds;
    final platform = Theme.of(context).platform;
    if (_needsBottom) {
      // The bottom padding and typing row sit below scroll offset 0.
      _needsBottom = false;
      _afterFrame(_jumpToBottom);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = widget.padding ?? theme.listPadding;
        final width = constraints.maxWidth - padding.horizontal;
        final maxContentWidth = math
            .max(0, width * theme.maxBubbleWidthFactor)
            .toDouble();
        final horizontal = EdgeInsets.only(
          left: padding.left,
          right: padding.right,
        );
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                controller: _scroll,
                reverse: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: platform == TargetPlatform.android
                    ? const ClampingScrollPhysics()
                    : null,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
                center: _centerKey,
                // Slivers before the center are laid out from the center
                // downwards: the last of them sits right below it.
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
                  if (c.typingUserIds.isNotEmpty)
                    SliverPadding(
                      padding: horizontal,
                      sliver: SliverToBoxAdapter(child: _typing(context)),
                    ),
                  // Laid out eagerly so the bottom is exact when a new
                  // message arrives below the viewport.
                  _sliver(
                    _newer,
                    _newerIndex,
                    _newerList,
                    padding,
                    maxContentWidth,
                    delayCacheArea: false,
                  ),
                  _sliver(
                    _older,
                    _olderIndex,
                    _olderList,
                    padding,
                    maxContentWidth,
                    key: _centerKey,
                  ),
                  SliverPadding(
                    padding: horizontal,
                    sliver: SliverToBoxAdapter(child: _historyEdge(context)),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: padding.top)),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _headerVisible,
                builder: (context, visible, _) => ValueListenableBuilder(
                  valueListenable: _header,
                  builder: (context, label, _) =>
                      FloatingDateHeader(label: label, visible: visible),
                ),
              ),
            ),
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: _scrollButton(context),
            ),
          ],
        );
      },
    );
  }

  Widget _scrollButton(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showButton,
      builder: (context, show, _) => AnimatedScale(
        scale: show ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: ValueListenableBuilder<int>(
          valueListenable: _controller.newMessagesCount,
          builder: (context, count, _) {
            final child = ScrollToBottomButton(
              unreadCount: count,
              onPressed: () => unawaited(scrollToBottom()),
              tooltip: widget.strings.scrollToBottom,
            );
            return widget.builders.scrollToBottomBuilder?.call(
                  context,
                  count,
                  () => unawaited(scrollToBottom()),
                  child,
                ) ??
                child;
          },
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ChatListItem item, double maxWidth) {
    final builders = widget.builders;
    final Widget child;
    switch (item) {
      case MessageListItem():
        child = _RowTracker(
          id: item.message.localId,
          rows: _rows,
          child: _message(context, item, maxWidth),
        );
      case DateSeparatorItem(:final day):
        final separator = DateSeparator(
          label: widget.formatters.formatDateSeparator(
            day,
            widget.strings,
            now: _controller.kit.clock(),
          ),
        );
        child =
            builders.dateSeparatorBuilder?.call(context, day, separator) ??
            separator;
      case UnreadDividerItem():
        final divider = UnreadDivider(label: widget.strings.newMessages);
        child =
            builders.unreadDividerBuilder?.call(context, divider) ?? divider;
    }
    return KeyedSubtree(key: ValueKey<Object>(item.key), child: child);
  }

  Widget _message(BuildContext context, MessageListItem item, double maxWidth) {
    final c = _controller;
    final builders = widget.builders;
    final config = _config;
    final theme = ChatTheme.of(context);
    final message = item.message;
    final mine = message.authorId == c.currentUserId;
    final room = c.room;
    final isGroup = room != null && !room.isDirect;
    final author = c.users[message.authorId];
    final replyToId = message.replyToId;
    final context_ = MessageContext(
      message: message,
      author: author,
      isMine: mine,
      groupPosition: item.groupPosition,
      index: item.messageIndex,
      uploadProgress: message.status.isLocal
          ? c.progressOf(message.localId)
          : _noProgress,
      room: room,
      repliedTo: replyToId == null ? null : c.messageById(replyToId),
      seenBy: mine && isGroup ? c.seenBy(message) : const [],
      isSelected: _selected.contains(message.localId),
      isHighlighted: c.highlightedId.value == message.localId,
    );

    final content =
        widget.contentBuilder?.call(context, context_) ??
        _FallbackContent(
          message: context_,
          strings: widget.strings,
          builders: builders,
        );

    final isSystem = message is SystemMessage;
    final showAvatar =
        !mine && !isSystem && (isGroup || config.showAvatarsInDirect);
    Widget? avatar;
    if (showAvatar && item.groupPosition.isLast) {
      final fallback = ChatAvatar(
        name: author?.name ?? '',
        url: author?.avatarUrl,
      );
      avatar =
          builders.avatarBuilder?.call(context, context_, fallback) ?? fallback;
      final onAvatarTap = widget.onAvatarTap;
      if (onAvatarTap != null) {
        avatar = GestureDetector(
          onTap: () => onAvatarTap(message.authorId),
          child: avatar,
        );
      }
    }

    Widget? name;
    final authorName = author?.name ?? '';
    if (!mine &&
        !isSystem &&
        isGroup &&
        config.showAuthorNamesInGroup &&
        item.groupPosition.isFirst &&
        authorName.isNotEmpty) {
      final fallback = Text(authorName, style: theme.authorNameStyle);
      name =
          builders.authorNameBuilder?.call(context, context_, fallback) ??
          fallback;
    }

    final onTap = widget.onMessageTap;
    final onLongPress = widget.onMessageLongPress;
    final row = MessageRow(
      message: context_,
      content: content,
      maxContentWidth: maxWidth,
      showAvatar: showAvatar,
      avatar: avatar,
      authorName: name,
      onTap: onTap == null ? null : () => onTap(context_),
      onLongPress: onLongPress == null ? null : () => onLongPress(context_),
    );
    return builders.messageBuilder?.call(context, context_, row) ?? row;
  }

  Widget _typing(BuildContext context) {
    final c = _controller;
    final ids = c.typingUserIds;
    final users = <ChatUser>[for (final id in ids) ?c.users[id]];
    final names = [for (final u in users) u.name];
    final child = TypingIndicator(
      label: names.isEmpty ? null : widget.strings.typing(names),
    );
    return widget.builders.typingBuilder?.call(
          context,
          TypingState(roomId: c.roomId, userIds: ids.toSet()),
          users,
          child,
        ) ??
        child;
  }

  /// The top of the list: a spinner while older messages load, or the
  /// start-of-conversation note.
  Widget _historyEdge(BuildContext context) {
    final c = _controller;
    final theme = ChatTheme.of(context);
    if (!c.hasMoreOlder) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            widget.strings.startOfConversation,
            style: theme.systemMessageStyle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: c.isLoadingOlder
          ? const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }
}

/// Plain content used until the app (or the kit's message widgets)
/// provides a [MessageContentBuilder].
class _FallbackContent extends StatelessWidget {
  const _FallbackContent({
    required this.message,
    required this.strings,
    required this.builders,
  });

  final MessageContext message;
  final ChatStrings strings;
  final ChatBuilders builders;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final m = message.message;
    if (m is SystemMessage) {
      return Text(
        strings.system(m.code, m.args),
        style: theme.systemMessageStyle,
        textAlign: TextAlign.center,
      );
    }
    if (m is CustomMessage && !m.isDeleted) {
      final custom = builders.customBuilders[m.customType];
      if (custom != null) return custom(context, message);
    }
    final mine = message.isMine;
    final text = m.isDeleted
        ? strings.messageDeleted
        : switch (m) {
            TextMessage(:final text) => text,
            ImageMessage(:final caption, :final images) =>
              caption ?? strings.photos(images.length),
            VideoMessage(:final caption) => caption ?? strings.video,
            AudioMessage() => strings.voice,
            FileMessage(:final file) => file.name ?? strings.file,
            SystemMessage() || CustomMessage() => strings.unsupportedMessage,
          };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mine ? theme.outgoingBubbleColor : theme.incomingBubbleColor,
        borderRadius: BorderRadius.circular(theme.bubbleRadius),
      ),
      child: Padding(
        padding: theme.bubblePadding,
        child: Text(
          text,
          style: mine ? theme.outgoingTextStyle : theme.incomingTextStyle,
        ),
      ),
    );
  }
}

/// Keeps [rows] pointing at the mounted context of each message row.
class _RowTracker extends StatefulWidget {
  const _RowTracker({
    required this.id,
    required this.rows,
    required this.child,
  });

  final String id;
  final Map<String, BuildContext> rows;
  final Widget child;

  @override
  State<_RowTracker> createState() => _RowTrackerState();
}

class _RowTrackerState extends State<_RowTracker> {
  @override
  void initState() {
    super.initState();
    widget.rows[widget.id] = context;
  }

  @override
  void didUpdateWidget(_RowTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _forget(oldWidget.id);
      widget.rows[widget.id] = context;
    }
  }

  @override
  void dispose() {
    _forget(widget.id);
    super.dispose();
  }

  void _forget(String id) {
    if (identical(widget.rows[id], context)) widget.rows.remove(id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoProgress implements ValueListenable<double?> {
  const _NoProgress();

  @override
  double? get value => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
