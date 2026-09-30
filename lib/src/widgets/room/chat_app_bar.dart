import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_kit/src/models/presence.dart';
import 'package:flutter_chat_kit/src/widgets/common/room_avatar.dart';

/// Wraps or replaces part of the room app bar.
typedef ChatAppBarBuilder =
    Widget Function(
      BuildContext context,
      ChatRoomController room,
      Widget defaultChild,
    );

/// Customization of [ChatAppBar].
@immutable
class ChatAppBarOptions {
  const ChatAppBarOptions({
    this.actions = const [],
    this.titleBuilder,
    this.subtitleBuilder,
    this.leadingBuilder,
    this.onTitleTap,
    this.backgroundColor,
    this.showBack = true,
  });

  /// App actions, such as call buttons or a menu.
  final List<Widget> actions;

  /// The room name.
  final ChatAppBarBuilder? titleBuilder;

  /// Typing, presence or member count line (the default child is an empty
  /// box when there is nothing to show).
  final ChatAppBarBuilder? subtitleBuilder;

  /// The room avatar before the title.
  final ChatAppBarBuilder? leadingBuilder;

  /// Usually opens the room or profile details.
  final VoidCallback? onTitleTap;
  final Color? backgroundColor;

  /// Shows a back button when the route can be popped.
  final bool showBack;

  ChatAppBarOptions copyWith({
    List<Widget>? actions,
    ChatAppBarBuilder? titleBuilder,
    ChatAppBarBuilder? subtitleBuilder,
    ChatAppBarBuilder? leadingBuilder,
    VoidCallback? onTitleTap,
    Color? backgroundColor,
    bool? showBack,
  }) {
    return ChatAppBarOptions(
      actions: actions ?? this.actions,
      titleBuilder: titleBuilder ?? this.titleBuilder,
      subtitleBuilder: subtitleBuilder ?? this.subtitleBuilder,
      leadingBuilder: leadingBuilder ?? this.leadingBuilder,
      onTitleTap: onTitleTap ?? this.onTitleTap,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showBack: showBack ?? this.showBack,
    );
  }
}

/// App bar of a room: avatar, name, and a subtitle that shows, by priority,
/// who is typing, the peer's presence (direct rooms), or the member count
/// (groups).
///
/// Presence arrives while an inbox is open (see
/// `ChatRepository.presenceChanges`).
class ChatAppBar extends StatefulWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.controller,
    this.options = const ChatAppBarOptions(),
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final ChatRoomController controller;
  final ChatAppBarOptions options;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<ChatAppBar> createState() => _ChatAppBarState();
}

class _ChatAppBarState extends State<ChatAppBar> {
  StreamSubscription<Presence>? _presenceSub;
  String? _peerId;
  Presence? _presence;

  ChatRoomController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    _syncPeer();
  }

  @override
  void didUpdateWidget(ChatAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, _c)) {
      oldWidget.controller.removeListener(_onController);
      _c.addListener(_onController);
      _syncPeer();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    unawaited(_presenceSub?.cancel());
    super.dispose();
  }

  void _onController() {
    _syncPeer();
    setState(() {});
  }

  void _syncPeer() {
    final room = _c.room;
    final peerId = room != null && room.isDirect
        ? room.otherUserId(_c.currentUserId)
        : null;
    if (peerId == _peerId && _presenceSub != null) return;
    unawaited(_presenceSub?.cancel());
    _presenceSub = null;
    _peerId = peerId;
    if (peerId == null) {
      _presence = null;
      return;
    }
    final repository = _c.kit.repository;
    _presence = repository.presence(peerId);
    _presenceSub = repository.watchPresence(peerId).listen((presence) {
      if (mounted) setState(() => _presence = presence);
    });
  }

  String? _subtitle() {
    final strings = widget.strings;
    final typing = [for (final id in _c.typingUserIds) ?_c.users[id]?.name];
    if (typing.isNotEmpty) return strings.typing(typing);
    final room = _c.room;
    if (room == null) return null;
    if (room.isDirect) {
      final presence = _presence;
      if (presence == null) return null;
      if (presence.isOnline) return strings.online;
      final lastSeen = presence.lastSeenAt;
      if (lastSeen == null) return null;
      return strings.lastSeen(
        widget.formatters.formatLastSeen(lastSeen, strings),
      );
    }
    return strings.members(room.members.length);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final theme = ChatTheme.of(context);
    final style = theme.appBar;
    final room = _c.room;
    final isTyping = _c.typingUserIds.any(_c.users.containsKey);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final showBack = options.showBack && canPop;

    var avatar = room == null
        ? SizedBox.square(dimension: style.avatarSize)
        : RoomAvatar(
            room: room,
            currentUserId: _c.currentUserId,
            users: _c.users,
            size: style.avatarSize,
            online: _presence?.isOnline ?? false,
          );
    if (options.leadingBuilder case final build?) {
      avatar = build(context, _c, avatar);
    }

    Widget title = Text(
      room == null ? '' : roomDisplayName(room, _c.currentUserId, _c.users),
      style: style.titleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (options.titleBuilder case final build?) {
      title = build(context, _c, title);
    }

    final text = _subtitle();
    var subtitle = text == null
        ? const SizedBox.shrink()
        : Text(
            text,
            style: isTyping ? style.typingStyle : style.subtitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    if (options.subtitleBuilder case final build?) {
      subtitle = build(context, _c, subtitle);
    }

    Widget heading = Row(
      children: [
        avatar,
        SizedBox(width: style.gap),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, subtitle],
          ),
        ),
      ],
    );
    if (options.onTitleTap case final onTap?) {
      heading = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.size(8)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.size(4)),
          child: heading,
        ),
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const BackButtonIcon(),
              tooltip: widget.strings.back,
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      titleSpacing: showBack ? 0 : NavigationToolbar.kMiddleSpacing,
      backgroundColor: options.backgroundColor ?? style.backgroundColor,
      title: heading,
      actions: options.actions,
    );
  }
}
