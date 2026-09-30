import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/chat_profile_switcher.dart';
import 'package:flutter_chat_kit/src/models/chat_profile.dart';
import 'package:flutter_chat_kit/src/widgets/common/chat_avatar.dart';
import 'package:flutter_chat_kit/src/widgets/profile/chat_profile_scope.dart';

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
    this.avatarSize = 32,
    this.itemBuilder,
    this.onSwitchFailed,
    super.key,
  });

  /// Defaults to the nearest `ChatProfileScope`.
  final ChatProfileSwitcher? switcher;
  final ChatStrings strings;
  final double avatarSize;
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
          child: Padding(padding: const EdgeInsets.all(8), child: icon),
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
    final Widget child = Row(
      children: [
        ChatAvatar(name: profile.name, url: profile.avatarUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (profile.isBusiness)
                Row(
                  children: [
                    Icon(Icons.storefront, size: 14, color: theme.iconColor),
                    const SizedBox(width: 4),
                    Text(
                      strings.businessProfile,
                      style: TextStyle(fontSize: 12, color: theme.iconColor),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (isActive)
          Icon(Icons.check, color: scheme.primary)
        else if (profile.unreadCount > 0)
          Semantics(
            label: strings.unreadCount(profile.unreadCount),
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.unreadBadgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                profile.unreadCount > 99 ? '99+' : '${profile.unreadCount}',
                style: theme.unreadBadgeTextStyle,
              ),
            ),
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
              library: 'flutter_chat_kit',
              context: ErrorDescription('while switching chat profile'),
            ),
          );
        }
      }),
    );
  }
}
