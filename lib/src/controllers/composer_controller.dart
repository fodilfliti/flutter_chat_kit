import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_pro/src/controllers/chat_room_controller.dart';
import 'package:flutter_chat_pro/src/models/attachment.dart';
import 'package:flutter_chat_pro/src/models/message.dart';

/// State of the input bar of a room: text, reply target, message being
/// edited, staged attachments, draft persistence and typing notifications.
///
/// - The draft (text and reply target) is restored on creation and saved
///   [draftDebounce] after the last change.
/// - "Typing" is sent at most every `ChatConfig.typingThrottle` while the
///   user types, and "stopped" after `ChatConfig.typingTimeout` of
///   inactivity, on submit, or on dispose.
class ComposerController extends ChangeNotifier {
  ComposerController(
    this.room, {
    this.draftDebounce = const Duration(milliseconds: 400),
  }) : text = TextEditingController() {
    text.addListener(_onText);
    restored = _restoreDraft();
  }

  final ChatRoomController room;
  final TextEditingController text;
  final Duration draftDebounce;

  /// Completes once the saved draft (if any) was put back.
  late final Future<void> restored;

  Message? _replyTo;
  Message? _editing;
  String? _textBeforeEdit;
  final List<Attachment> _staged = [];
  Timer? _draftTimer;
  Timer? _typingIdle;
  DateTime? _typingSentAt;
  bool _typingOn = false;
  bool _programmatic = false;
  bool _userTyped = false;
  bool _submitting = false;
  bool _disposed = false;
  String _lastText = '';

  String get roomId => room.roomId;

  Message? get replyTo => _replyTo;

  /// The message being edited; [submit] replaces its text.
  Message? get editing => _editing;

  bool get isEditing => _editing != null;

  List<Attachment> get staged => List.unmodifiable(_staged);

  bool get isSubmitting => _submitting;

  bool get canSend {
    if (_submitting) return false;
    final value = text.text.trim();
    final editing = _editing;
    if (editing != null) {
      return value.isNotEmpty && value != _editableText(editing);
    }
    return value.isNotEmpty || _staged.isNotEmpty;
  }

  /// Whether [message] can be edited through [startEdit].
  static bool canEdit(Message message) =>
      message is TextMessage ||
      message is ImageMessage ||
      message is VideoMessage;

  void reply(Message message) {
    if (_editing != null) _endEdit();
    _replyTo = message;
    _scheduleDraft();
    notifyListeners();
  }

  /// Puts the text (or caption) of [message] in the field for editing.
  void startEdit(Message message) {
    if (!canEdit(message)) return;
    _textBeforeEdit ??= text.text;
    _editing = message;
    _replyTo = null;
    _setText(_editableText(message));
    _stopTyping();
    notifyListeners();
  }

  /// Leaves edit mode (restoring the previous text) and drops the reply
  /// target.
  void cancel() {
    if (_editing != null) _endEdit();
    _replyTo = null;
    _scheduleDraft();
    notifyListeners();
  }

  void stage(List<Attachment> files) {
    if (files.isEmpty) return;
    _staged.addAll(files);
    notifyListeners();
  }

  void unstage(Attachment file) {
    if (_staged.remove(file)) notifyListeners();
  }

  void clearStaged() {
    if (_staged.isEmpty) return;
    _staged.clear();
    notifyListeners();
  }

  /// Sends the text, the staged files (with the text as caption), or the
  /// edit. Errors (such as an attachment over the size limit) are rethrown
  /// and the input is kept.
  Future<void> submit() async {
    if (!canSend) return;
    final body = text.text;
    final editing = _editing;
    final replyToId = _replyTo?.id;
    final files = List.of(_staged);
    _submitting = true;
    notifyListeners();
    try {
      if (editing != null) {
        await room.edit(editing.id, body);
      } else if (files.isNotEmpty) {
        await room.sendMedia(files, caption: body, replyToId: replyToId);
      } else {
        await room.sendText(body, replyToId: replyToId);
      }
      if (_disposed) return;
      if (editing != null) {
        _endEdit();
      } else {
        _replyTo = null;
        _staged.clear();
        _setText('');
      }
      _stopTyping();
      _draftTimer?.cancel();
      await _saveDraft();
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ------------------------------------------------------------ internals

  void _onText() {
    final value = text.text;
    if (value == _lastText) return;
    _lastText = value;
    if (_programmatic) return;
    _userTyped = true;
    _scheduleDraft();
    _typing();
    notifyListeners();
  }

  void _setText(String value) {
    _programmatic = true;
    text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _programmatic = false;
  }

  void _endEdit() {
    _editing = null;
    _setText(_textBeforeEdit ?? '');
    _textBeforeEdit = null;
  }

  Future<void> _restoreDraft() async {
    final kit = room.kit;
    if (!kit.isOpen) return;
    final draft = await kit.cache.draft(roomId);
    if (_disposed || _userTyped || draft == null) return;
    _setText(draft.text);
    final replyToId = draft.replyToId;
    if (replyToId != null) {
      _replyTo = await kit.cache.messageByAnyId(replyToId);
    }
    if (!_disposed) notifyListeners();
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDebounce, _saveDraftInBackground);
  }

  void _saveDraftInBackground() {
    unawaited(
      _saveDraft().catchError(
        (Object _) {},
        // The kit may close while the draft is written.
        test: (_) => !room.kit.isOpen,
      ),
    );
  }

  Future<void> _saveDraft() async {
    final kit = room.kit;
    if (!kit.isOpen) return;
    // While editing, the draft is the text from before the edit.
    final value = _editing == null ? text.text : (_textBeforeEdit ?? '');
    await kit.cache.saveDraft(roomId, value, replyToId: _replyTo?.id);
  }

  void _typing() {
    if (_editing != null || text.text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    final config = room.kit.config;
    final now = room.kit.clock();
    final sentAt = _typingSentAt;
    if (!_typingOn ||
        sentAt == null ||
        now.difference(sentAt) >= config.typingThrottle) {
      _typingOn = true;
      _typingSentAt = now;
      _sendTyping(typing: true);
    }
    _typingIdle?.cancel();
    _typingIdle = Timer(config.typingTimeout, _stopTyping);
  }

  void _stopTyping() {
    _typingIdle?.cancel();
    _typingIdle = null;
    if (!_typingOn) return;
    _typingOn = false;
    _typingSentAt = null;
    _sendTyping(typing: false);
  }

  void _sendTyping({required bool typing}) {
    final kit = room.kit;
    if (!kit.isOpen) return;
    unawaited(
      kit.repository
          .setTyping(roomId, typing: typing)
          .then<void>(
            (_) {},
            // Typing is best effort.
            onError: (Object _) {},
          ),
    );
  }

  static String _editableText(Message message) => switch (message) {
    TextMessage(:final text) => text,
    ImageMessage(:final caption) ||
    VideoMessage(:final caption) => caption ?? '',
    _ => '',
  };

  @visibleForTesting
  bool get hasPendingTimers =>
      (_draftTimer?.isActive ?? false) || (_typingIdle?.isActive ?? false);

  @override
  void dispose() {
    _disposed = true;
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      _saveDraftInBackground();
    }
    _stopTyping();
    text
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }
}
