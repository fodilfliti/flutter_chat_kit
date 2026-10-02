import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_chat_pro/src/controllers/audio_player_hub.dart';

/// [AudioBackend] on `audioplayers`.
class AudioplayersBackend implements AudioBackend {
  final _player = AudioPlayer();

  @override
  Stream<Duration> get positions => _player.onPositionChanged;

  @override
  Stream<Duration> get durations => _player.onDurationChanged;

  @override
  Stream<void> get completions => _player.onPlayerComplete;

  @override
  Future<void> play({String? url, String? localPath}) {
    final source = localPath != null
        ? DeviceFileSource(localPath)
        : UrlSource(url ?? '');
    return _player.play(source);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);

  @override
  Future<void> dispose() => _player.dispose();
}
