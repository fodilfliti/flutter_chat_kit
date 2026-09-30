import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_kit/src/config/chat_formatters.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/composer_controller.dart';
import 'package:flutter_chat_kit/src/controllers/voice_recorder_controller.dart';
import 'package:flutter_chat_kit/src/media/default_pickers.dart';
import 'package:flutter_chat_kit/src/models/attachment.dart';
import 'package:flutter_chat_kit/src/models/message.dart';
import 'package:flutter_chat_kit/src/widgets/composer/attachment_sheet.dart';
import 'package:flutter_chat_kit/src/widgets/composer/reply_edit_banner.dart';
import 'package:flutter_chat_kit/src/widgets/composer/staged_attachments.dart';
import 'package:flutter_chat_kit/src/widgets/composer/voice_record_button.dart';
import 'package:flutter_chat_kit/src/widgets/messages/audio_message_view.dart';
import 'package:lemsa_core_kit/lemsa_core_kit.dart';
import 'package:path/path.dart' as p;

/// The input bar of a room: reply / edit banner, staged files, text field,
/// attachment button, and a send button that becomes a hold-to-record mic
/// when there is nothing to send.
///
/// - Enter sends on desktop and web (Shift+Enter adds a line); Esc cancels
///   the reply or edit.
/// - Attachments and voice are hidden without a `ChatKit.uploader`, and
///   while editing.
/// - Files come from [onAttachmentPick] or the default pickers; the outbox
///   uploads them after sending.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,
    this.onAttachmentPick,
    this.extraAttachmentOptions = const [],
    this.leading,
    this.trailing,
    this.enableVoice = true,
    this.enableAttachments = true,
    this.inputDecoration,
    this.maxLines = 6,
    this.sendOnEnter,
    this.recorder,
    this.onError,
    this.focusNode,
    this.strings = const ChatStrings(),
    this.formatters = const ChatFormatters(),
    super.key,
  });

  final ComposerController controller;

  /// Replaces the default `image_picker` / `file_picker` flows.
  final AttachmentPicker? onAttachmentPick;

  /// Added after camera, gallery, video and file in the attachment sheet.
  final List<AttachmentOption> extraAttachmentOptions;
  final Widget? leading;
  final Widget? trailing;
  final bool enableVoice;
  final bool enableAttachments;

  /// Replaces the default rounded, filled decoration.
  final InputDecoration? inputDecoration;
  final int maxLines;

  /// Defaults to true on desktop and web.
  final bool? sendOnEnter;

  /// Defaults to one created with `ChatConfig.minVoiceDuration`.
  final VoiceRecorderController? recorder;

  /// Called when sending throws; defaults to a snack bar.
  final ValueChanged<Object>? onError;
  final FocusNode? focusNode;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  VoiceRecorderController? _ownRecorder;
  FocusNode? _ownFocus;
  final _drag = ValueNotifier<Offset>(Offset.zero);

  ComposerController get _c => widget.controller;

  ChatStrings get _strings => widget.strings;

  VoiceRecorderController get _recorder =>
      widget.recorder ??
      (_ownRecorder ??= VoiceRecorderController(
        minDuration: _c.room.kit.config.minVoiceDuration,
      ));

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  String get _previewId => 'flutter_chat_kit/composer/${_c.roomId}';

  bool get _sendOnEnter =>
      widget.sendOnEnter ??
      (kIsWeb ||
          switch (defaultTargetPlatform) {
            TargetPlatform.windows ||
            TargetPlatform.macOS ||
            TargetPlatform.linux => true,
            _ => false,
          });

  @override
  void dispose() {
    _ownRecorder?.dispose();
    _ownFocus?.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _show(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _fail(Object error) {
    final onError = widget.onError;
    if (onError != null) return onError(error);
    _show(
      error is ValidationFailure
          ? _strings.attachmentTooLarge
          : _strings.failedToSend,
    );
  }

  Future<void> _submit() async {
    if (!_c.canSend) return;
    try {
      await _c.submit();
    } on Object catch (e) {
      if (mounted) _fail(e);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape &&
        (_c.replyTo != null || _c.isEditing)) {
      _c.cancel();
      return KeyEventResult.handled;
    }
    if (!_sendOnEnter ||
        (key != LogicalKeyboardKey.enter &&
            key != LogicalKeyboardKey.numpadEnter) ||
        HardwareKeyboard.instance.isShiftPressed ||
        _c.text.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    unawaited(_submit());
    return KeyEventResult.handled;
  }

  Future<void> _attach() async {
    final options = [
      ...AttachmentOption.defaults(_strings),
      ...widget.extraAttachmentOptions,
    ];
    final chosen = await AttachmentSheet.show(context, options: options);
    if (chosen == null || !mounted) return;
    final source = chosen.source;
    if (source == null) {
      chosen.onSelected?.call();
      return;
    }
    final pick =
        widget.onAttachmentPick ?? const DefaultAttachmentPicker().call;
    final List<Attachment> files;
    try {
      files = await pick(context, source);
    } on Object catch (e) {
      if (mounted) _fail(e);
      return;
    }
    if (!mounted || files.isEmpty) return;
    final limit = _c.room.kit.config.maxAttachmentBytes;
    final accepted = [
      for (final f in files)
        if (limit == null || (f.size ?? 0) <= limit) f,
    ];
    if (accepted.length < files.length) _show(_strings.attachmentTooLarge);
    _c.stage(accepted);
  }

  Future<void> _sendVoice(VoiceRecording recording) async {
    final file = File(recording.path);
    final attachment = Attachment(
      mimeType: 'audio/mp4',
      localPath: recording.path,
      size: file.existsSync() ? file.lengthSync() : null,
      duration: recording.duration,
      name: p.basename(recording.path),
    );
    try {
      await _c.room.sendVoice(
        attachment,
        recording.duration,
        recording.waveform,
        replyToId: _c.replyTo?.id,
      );
      if (_c.replyTo != null) _c.cancel();
    } on Object catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _stopPreview() async {
    final audio = _c.room.kit.audio;
    if (audio.currentId == _previewId) await audio.stop();
  }

  Future<void> _sendLockedOrReviewed() async {
    final recorder = _recorder;
    final VoiceRecording? recording;
    if (recorder.state == RecorderState.review) {
      recording = recorder.recording;
      await _stopPreview();
      recorder.reset();
    } else {
      recording = await recorder.stop();
    }
    if (recording == null) {
      _show(_strings.holdToRecord);
      return;
    }
    await _sendVoice(recording);
  }

  Future<void> _discardVoice() async {
    await _stopPreview();
    await _recorder.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final c = _c;
    final kit = c.room.kit;
    return Material(
      color: theme.composerBackgroundColor,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([c, _recorder]),
          builder: (context, _) {
            final canMedia = kit.canSendMedia && !c.isEditing;
            final voiceOn = widget.enableVoice && canMedia;
            final attachOn = widget.enableAttachments && canMedia;
            final state = _recorder.state;
            final recording = voiceOn && state != RecorderState.idle;
            final showSend =
                !voiceOn ||
                c.isEditing ||
                c.text.text.trim().isNotEmpty ||
                c.staged.isNotEmpty;

            final editing = c.editing;
            final replyTo = c.replyTo;
            Widget? banner;
            if (editing != null) {
              banner = ReplyEditBanner(
                message: editing,
                isEditing: true,
                onClose: c.cancel,
                strings: _strings,
              );
            } else if (replyTo != null) {
              banner = ReplyEditBanner(
                message: replyTo,
                isEditing: false,
                authorName: replyTo.authorId == c.room.currentUserId
                    ? _strings.you
                    : c.room.users[replyTo.authorId]?.name,
                onClose: c.cancel,
                strings: _strings,
              );
            }

            final Widget action;
            if (recording && state != RecorderState.recording) {
              action = _SendButton(
                key: const ValueKey('send-voice'),
                onPressed: () => unawaited(_sendLockedOrReviewed()),
                tooltip: _strings.send,
              );
            } else if (showSend && !recording) {
              action = _SendButton(
                key: const ValueKey('send'),
                onPressed: c.canSend ? () => unawaited(_submit()) : null,
                tooltip: _strings.send,
              );
            } else {
              action = VoiceRecordButton(
                key: const ValueKey('mic'),
                recorder: _recorder,
                onRecorded: _sendVoice,
                onHint: _show,
                drag: _drag,
                strings: _strings,
              );
            }

            final row = Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.leading case final leading?)
                  KeyedSubtree(key: const ValueKey('leading'), child: leading),
                if (attachOn && !recording)
                  IconButton(
                    key: const ValueKey('attach'),
                    onPressed: () => unawaited(_attach()),
                    tooltip: _strings.attach,
                    icon: Icon(Icons.attach_file, color: theme.iconColor),
                  ),
                Expanded(
                  key: const ValueKey('field'),
                  child: recording
                      ? _RecordingBar(
                          recorder: _recorder,
                          drag: _drag,
                          previewId: _previewId,
                          onDelete: () => unawaited(_discardVoice()),
                          strings: _strings,
                          formatters: widget.formatters,
                        )
                      : _input(theme),
                ),
                if (widget.trailing case final trailing?)
                  KeyedSubtree(
                    key: const ValueKey('trailing'),
                    child: trailing,
                  ),
                Padding(
                  key: const ValueKey('action'),
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    // The outgoing button must not take taps meant for the
                    // incoming one.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final child in previous)
                          IgnorePointer(child: child),
                        ?current,
                      ],
                    ),
                    child: action,
                  ),
                ),
              ],
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?banner,
                if (c.staged.isNotEmpty)
                  StagedAttachments(
                    files: c.staged,
                    onRemove: c.unstage,
                    strings: _strings,
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                      child: row,
                    ),
                    if (state == RecorderState.recording && voiceOn)
                      PositionedDirectional(
                        end: 10,
                        bottom: 64,
                        child: _LockHint(drag: _drag, strings: _strings),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _input(ChatTheme theme) {
    final decoration =
        widget.inputDecoration ??
        InputDecoration(
          hintText: _strings.typeMessage,
          hintStyle: theme.composerHintStyle,
          filled: true,
          fillColor: theme.composerInputColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextField(
        controller: _c.text,
        focusNode: _focus,
        minLines: 1,
        maxLines: widget.maxLines,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: theme.composerTextStyle,
        decoration: decoration,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: theme.sendButtonColor,
        foregroundColor: Colors.white,
        fixedSize: const Size.square(44),
      ),
      icon: const Icon(Icons.send_rounded, size: 20),
    );
  }
}

/// Replaces the text field while recording: elapsed time and "slide to
/// cancel" (holding), delete / time / stop (locked), or delete / play /
/// waveform (review).
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.recorder,
    required this.drag,
    required this.previewId,
    required this.onDelete,
    required this.strings,
    required this.formatters,
  });

  final VoiceRecorderController recorder;
  final ValueListenable<Offset> drag;
  final String previewId;
  final VoidCallback onDelete;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final style = theme.composerTextStyle;
    final state = recorder.state;
    final time = Text(
      formatters.formatDuration(recorder.elapsed),
      style: style,
    );
    final dot = Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: Icon(
        Icons.fiber_manual_record,
        color: theme.failedColor,
        size: 14,
      ),
    );
    final delete = IconButton(
      onPressed: onDelete,
      tooltip: strings.delete,
      icon: Icon(Icons.delete_outline, color: theme.failedColor),
    );
    final Widget content;
    switch (state) {
      case RecorderState.recording:
        content = Row(
          children: [
            dot,
            time,
            const Spacer(),
            ValueListenableBuilder<Offset>(
              valueListenable: drag,
              builder: (context, offset, child) {
                final dx = offset.dx.clamp(-80.0, 0.0);
                final rtl = Directionality.of(context) == TextDirection.rtl;
                return Opacity(
                  opacity: (1 + dx / 100).clamp(0.2, 1.0),
                  child: Transform.translate(
                    offset: Offset(rtl ? -dx : dx, 0),
                    child: child,
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, color: theme.iconColor, size: 18),
                  Text(strings.slideToCancel, style: theme.composerHintStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      case RecorderState.locked:
        content = Row(
          children: [
            delete,
            dot,
            time,
            const Spacer(),
            IconButton(
              onPressed: () => unawaited(recorder.stop(review: true)),
              tooltip: strings.stopRecording,
              icon: Icon(Icons.stop_circle_outlined, color: theme.failedColor),
            ),
          ],
        );
      case RecorderState.review:
        final recording = recorder.recording;
        content = Row(
          children: [
            delete,
            if (recording != null)
              Expanded(
                child: _Preview(
                  id: previewId,
                  recording: recording,
                  strings: strings,
                  formatters: formatters,
                ),
              ),
          ],
        );
      case RecorderState.idle:
        content = const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: theme.composerInputColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: content,
    );
  }
}

/// Plays back the reviewed recording through the kit's audio hub.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.id,
    required this.recording,
    required this.strings,
    required this.formatters,
  });

  final String id;
  final VoiceRecording recording;
  final ChatStrings strings;
  final ChatFormatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    final message = AudioMessage(
      id: id,
      localId: id,
      roomId: '',
      authorId: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      audio: Attachment(mimeType: 'audio/mp4', localPath: recording.path),
      duration: recording.duration,
      waveform: recording.waveform,
    );
    return AudioMessageView(
      message: message,
      color: theme.composerTextStyle.color ?? theme.iconColor,
      activeColor: theme.sendButtonColor,
      metaStyle: theme.composerHintStyle,
      strings: strings,
      formatters: formatters,
    );
  }
}

class _LockHint extends StatelessWidget {
  const _LockHint({required this.drag, required this.strings});

  final ValueListenable<Offset> drag;
  final ChatStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return ValueListenableBuilder<Offset>(
      valueListenable: drag,
      builder: (context, offset, child) => Transform.translate(
        offset: Offset(0, offset.dy.clamp(-60.0, 0.0)),
        child: child,
      ),
      child: Semantics(
        label: strings.slideUpToLock,
        child: Material(
          color: theme.composerInputColor,
          shape: const StadiumBorder(),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: theme.iconColor, size: 18),
                Icon(Icons.keyboard_arrow_up, color: theme.iconColor, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
