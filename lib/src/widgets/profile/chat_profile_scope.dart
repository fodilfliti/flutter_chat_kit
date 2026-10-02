import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/controllers/chat_kit.dart';
import 'package:flutter_chat_pro/src/controllers/chat_kit_scope.dart';
import 'package:flutter_chat_pro/src/controllers/chat_profile_switcher.dart';

/// Provides the [ChatProfileSwitcher] and the active profile's kit (as a
/// `ChatKitScope`) to [child].
///
/// On every switch [child] is removed for one frame and built again, so
/// open chat screens, and the controllers they own, are disposed before the
/// old kit closes. This also resets children with a `GlobalKey`, such as
/// the app's navigator: put the scope in `MaterialApp.builder`, or around
/// the chat tab.
class ChatProfileScope extends StatefulWidget {
  const ChatProfileScope({
    required this.switcher,
    required this.child,
    this.placeholder,
    super.key,
  });

  final ChatProfileSwitcher switcher;
  final Widget child;

  /// Shown while no kit is open (before `open`, after `close`) and for the
  /// frame between two profiles. Defaults to an empty box.
  final Widget? placeholder;

  static ChatProfileSwitcher? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwitcherScope>()?.notifier;

  static ChatProfileSwitcher of(BuildContext context) {
    final switcher = maybeOf(context);
    if (switcher == null) {
      throw FlutterError(
        'ChatProfileScope.of() called with a context that has no '
        'ChatProfileScope.\n'
        'Wrap your chat screens in ChatProfileScope(switcher: ..., '
        'child: ...).',
      );
    }
    return switcher;
  }

  @override
  State<ChatProfileScope> createState() => _ChatProfileScopeState();
}

class _ChatProfileScopeState extends State<ChatProfileScope> {
  ChatKit? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.switcher.kit;
    widget.switcher.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatProfileScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.switcher != widget.switcher) {
      oldWidget.switcher.removeListener(_changed);
      widget.switcher.addListener(_changed);
      _shown = widget.switcher.kit;
    }
  }

  @override
  void dispose() {
    widget.switcher.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final kit = widget.switcher.kit;
    if (kit == _shown) return;
    if (_shown == null || kit == null) {
      setState(() => _shown = kit);
      return;
    }
    // A child with a GlobalKey would move to the new subtree with its state;
    // leaving the tree for a frame disposes it.
    setState(() => _shown = null);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = widget.switcher.kit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = _shown;
    return _SwitcherScope(
      switcher: widget.switcher,
      child: kit == null
          ? widget.placeholder ?? const SizedBox.shrink()
          : ChatKitScope(
              kit: kit,
              child: KeyedSubtree(key: ObjectKey(kit), child: widget.child),
            ),
    );
  }
}

class _SwitcherScope extends InheritedNotifier<ChatProfileSwitcher> {
  const _SwitcherScope({
    required ChatProfileSwitcher switcher,
    required super.child,
  }) : super(notifier: switcher);
}

extension ChatProfileContext on BuildContext {
  ChatProfileSwitcher get chatProfiles => ChatProfileScope.of(this);
}
