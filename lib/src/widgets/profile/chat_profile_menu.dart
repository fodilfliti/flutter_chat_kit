import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:flutter_chat_pro/src/config/chat_theme.dart';
import 'package:flutter_chat_pro/src/controllers/chat_profile_switcher.dart';
import 'package:flutter_chat_pro/src/models/chat_profile.dart';
import 'package:flutter_chat_pro/src/widgets/common/chat_avatar.dart';
import 'package:flutter_chat_pro/src/widgets/inbox/room_tile.dart';
import 'package:flutter_chat_pro/src/widgets/profile/chat_profile_scope.dart';

/// Builds one entry of the profile menu.
typedef ChatProfileItemBuilder =
    Widget Function(
      BuildContext context,
      ChatProfile profile,
      Widget defaultChild, {
      required bool isActive,
    });

/// The active profile's avatar; tapping it opens a menu of every profile
/// (with business badges and unread counts) and switches to the chosen one.
/// Typically placed in the inbox app bar.
class ChatProfileMenuButton extends StatelessWidget {
  const ChatProfileMenuButton({
    this.switcher,
    this.strings = const ChatStrings(),
    this.avatarSize,
    this.itemBuilder,
    this.onSwitchFailed,
    super.key,
  });

  /// Defaults to the nearest `ChatProfileScope`.
  final ChatProfileSwitcher? switcher;
  final ChatStrings strings;

  /// Defaults to `ChatMessageListStyle.avatarSize`.
  final double? avatarSize;
  final ChatProfileItemBuilder? itemBuilder;

  /// Called when the chosen profile's kit fails to open; the previous
  /// profile stays active. Unhandled failures go to `FlutterError`.
  final void Function(Object error)? onSwitchFailed;

  @override
  Widget build(BuildContext context) {
    final s = switcher ?? ChatProfileScope.of(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final active = s.active;
        final othersUnread = s.profiles
            .where((p) => p.id != active.id)
            .fold<int>(0, (sum, p) => sum + p.unreadCount);
        Widget icon = ChatAvatar(
          name: active.name,
          url: active.avatarUrl,
          size: avatarSize,
        );
        if (othersUnread > 0) {
          icon = Badge(child: icon);
        }
        return PopupMenuButton<String>(
          tooltip: strings.switchProfile,
          enabled: !s.isSwitching,
          onSelected: (id) => _switch(s, id),
          itemBuilder: (context) => [
            for (final profile in s.profiles)
              PopupMenuItem<String>(
                value: profile.id,
                child: _item(
                  context,
                  profile,
                  isActive: profile.id == active.id,
                ),
              ),
          ],
          child: Padding(
            padding: EdgeInsets.all(ChatTheme.of(context).size(8)),
            child: icon,
          ),
        );
      },
    );
  }

  Widget _item(
    BuildContext context,
    ChatProfile profile, {
    required bool isActive,
  }) {
    final theme = ChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tile = theme.roomTile;
    final Widget child = Row(
      children: [
        ChatAvatar(
          name: profile.name,
          url: profile.avatarUrl,
          size: theme.size(36),
        ),
        SizedBox(width: theme.size(12)),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isActive ? tile.unreadTitleStyle : tile.titleStyle,
              ),
              if (profile.isBusiness)
                Row(
                  children: [
                    Icon(
                      Icons.storefront,
                      size: theme.size(14),
                      color: theme.iconColor,
                    ),
                    SizedBox(width: theme.size(4)),
                    Text(strings.businessProfile, style: tile.timeStyle),
                  ],
                ),
            ],
          ),
        ),
        if (isActive)
          Icon(Icons.check, color: scheme.primary, size: theme.size(24))
        else if (profile.unreadCount > 0)
          ChatUnreadBadge(
            count: profile.unreadCount,
            semanticLabel: strings.unreadCount(profile.unreadCount),
          ),
      ],
    );
    return itemBuilder?.call(context, profile, child, isActive: isActive) ??
        child;
  }

  void _switch(ChatProfileSwitcher switcher, String id) {
    unawaited(
      switcher.switchTo(id).catchError((Object error, StackTrace stack) {
        final report = onSwitchFailed;
        if (report != null) {
          report(error);
        } else {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'flutter_chat_pro',
              context: ErrorDescription('while switching chat profile'),
            ),
          );
        }
      }),
    );
  }
}
