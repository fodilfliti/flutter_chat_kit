import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_chat_pro/src/controllers/audio_player_hub.dart';
import 'package:web/web.dart' as web;

/// [AudioBackend] on an HTML audio element, used in WebAssembly builds in
/// place of `audioplayers`.
class AudioplayersBackend implements AudioBackend {
  /// Creates the audio element and listens to it.
  AudioplayersBackend() {
    _on('timeupdate', () => _positions.add(_toDuration(_audio.currentTime)));
    _on('durationchange', () {
      final seconds = _audio.duration;
      if (seconds.isFinite) _durations.add(_toDuration(seconds));
    });
    _on('ended', () => _completions.add(null));
  }

  final _audio = web.HTMLAudioElement();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<Duration> get durations => _durations.stream;

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Future<void> play({String? url, String? localPath}) async {
    _audio.src = localPath ?? url ?? '';
    await _audio.play().toDart;
  }

  @override
  Future<void> pause() async => _audio.pause();

  @override
  Future<void> resume() async {
    await _audio.play().toDart;
  }

  @override
  Future<void> stop() async {
    _audio
      ..pause()
      ..currentTime = 0;
  }

  @override
  Future<void> seek(Duration position) async {
    _audio.currentTime =
        position.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  Future<void> setSpeed(double speed) async => _audio.playbackRate = speed;

  @override
  Future<void> dispose() async {
    _audio
      ..pause()
      ..removeAttribute('src')
      ..load();
    await _positions.close();
    await _durations.close();
    await _completions.close();
  }

  void _on(String type, void Function() handler) {
    _audio.addEventListener(type, ((web.Event _) => handler()).toJS);
  }

  static Duration _toDuration(num seconds) => Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}
