import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';
import 'package:flutter_chat_kit/src/config/chat_theme.dart';
import 'package:flutter_chat_kit/src/controllers/voice_recorder_controller.dart';

/// The microphone button: hold to record, release to send, slide towards
/// the start edge to cancel, slide up to lock (keep recording hands-free).
/// A short tap shows `ChatStrings.holdToRecord` through [onHint].
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    required this.recorder,
    required this.onRecorded,
    this.onHint,
    this.drag,
    this.cancelDistance = 100,
    this.lockDistance = 70,
    this.size = 44,
    this.strings = const ChatStrings(),
    super.key,
  });

  final VoiceRecorderController recorder;

  /// Called with a recording released without cancelling or locking.
  final Future<void> Function(VoiceRecording recording) onRecorded;

  /// Shows a short message (hint, permission denied, too short).
  final ValueChanged<String>? onHint;

  /// Receives the finger offset while holding (start-edge direction is
  /// negative x in both text directions), for the slide-to-cancel label.
  final ValueNotifier<Offset>? drag;
  final double cancelDistance;
  final double lockDistance;
  final double size;
  final ChatStrings strings;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  Future<bool>? _starting;
  bool _holding = false;

  VoiceRecorderController get _recorder => widget.recorder;

  void _hint(String text) => widget.onHint?.call(text);

  void _onStart(LongPressStartDetails _) {
    _holding = true;
    widget.drag?.value = Offset.zero;
    final starting = _starting = _recorder.start();
    unawaited(
      starting.then((started) {
        if (!started) {
          _holding = false;
          _hint(widget.strings.microphoneDenied);
        } else if (!_holding && _recorder.state == RecorderState.recording) {
          // Released while the recorder was still starting.
          unawaited(_finish());
        }
      }, onError: (Object _) => _holding = false),
    );
  }

  void _onMove(LongPressMoveUpdateDetails details) {
    if (!_holding) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final raw = details.offsetFromOrigin;
    final offset = Offset(rtl ? -raw.dx : raw.dx, raw.dy);
    widget.drag?.value = offset;
    if (_recorder.state != RecorderState.recording) return;
    if (offset.dx < -widget.cancelDistance) {
      _holding = false;
      widget.drag?.value = Offset.zero;
      unawaited(_recorder.cancel());
    } else if (offset.dy < -widget.lockDistance) {
      _holding = false;
      widget.drag?.value = Offset.zero;
      _recorder.lock();
    }
  }

  void _onEnd(LongPressEndDetails _) {
    widget.drag?.value = Offset.zero;
    if (!_holding) return;
    _holding = false;
    unawaited(_finish());
  }

  Future<void> _finish() async {
    await _starting;
    if (_recorder.state != RecorderState.recording) return;
    final recording = await _recorder.stop();
    if (recording == null) {
      _hint(widget.strings.holdToRecord);
      return;
    }
    await widget.onRecorded(recording);
  }

  void _onCancel() {
    widget.drag?.value = Offset.zero;
    if (!_holding) return;
    _holding = false;
    unawaited(_starting?.then((_) => _recorder.cancel()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatTheme.of(context);
    return ListenableBuilder(
      listenable: _recorder,
      builder: (context, _) {
        final active = _recorder.state == RecorderState.recording;
        return Semantics(
          button: true,
          label: widget.strings.recordVoice,
          hint: widget.strings.holdToRecord,
          child: GestureDetector(
            onTap: () => _hint(widget.strings.holdToRecord),
            onLongPressStart: _onStart,
            onLongPressMoveUpdate: _onMove,
            onLongPressEnd: _onEnd,
            onLongPressCancel: _onCancel,
            child: AnimatedScale(
              scale: active ? 1.35 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: active ? theme.failedColor : theme.sendButtonColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
