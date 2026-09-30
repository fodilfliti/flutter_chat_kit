import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The platform player behind [AudioPlayerHub]; replaced in tests.
abstract interface class AudioBackend {
  Stream<Duration> get positions;
  Stream<Duration> get durations;

  /// Fires when playback reaches the end.
  Stream<void> get completions;
  Future<void> play({String? url, String? localPath});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

/// Plays one voice message at a time through a single player: starting
/// another pauses the current one. Bubbles listen to [position],
/// [duration] and [isPlaying] for their id only.
class AudioPlayerHub extends ChangeNotifier {
  AudioPlayerHub({AudioBackend Function()? backend})
    : _createBackend = backend ?? AudioplayersBackend.new;

  final AudioBackend Function() _createBackend;
  AudioBackend? _backend;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _positions = <String, ValueNotifier<Duration>>{};
  final _durations = <String, ValueNotifier<Duration?>>{};
  String? _currentId;
  bool _playing = false;
  double _speed = 1;

  /// The message whose audio is loaded (playing or paused).
  String? get currentId => _currentId;

  bool get isPlaying => _playing;

  /// Whether [id] is the one playing now.
  bool isPlayingId(String id) => _playing && _currentId == id;
  double get speed => _speed;

  ValueListenable<Duration> position(String id) =>
      _positions.putIfAbsent(id, () => ValueNotifier(Duration.zero));

  /// Known once the audio of [id] loaded, else null.
  ValueListenable<Duration?> duration(String id) =>
      _durations.putIfAbsent(id, () => ValueNotifier(null));

  /// Plays [id] from [localPath] (preferred) or [url]; resumes it when it is
  /// the paused current one. Pauses any other.
  Future<void> play(String id, {String? url, String? localPath}) async {
    final backend = _ensureBackend();
    if (_currentId == id && !_playing) {
      _playing = true;
      notifyListeners();
      await backend.resume();
      return;
    }
    if (_currentId == id) return;
    if (_currentId != null) await backend.stop();
    _currentId = id;
    _playing = true;
    notifyListeners();
    await backend.play(url: url, localPath: localPath);
    await backend.setSpeed(_speed);
    final start = _positions[id]?.value ?? Duration.zero;
    final total = _durations[id]?.value;
    if (start > Duration.zero && (total == null || start < total)) {
      await backend.seek(start);
    }
  }

  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _backend?.pause();
  }

  /// Seeks the current audio, or sets where [id] starts next time.
  Future<void> seek(Duration position, {String? id}) async {
    final target = id ?? _currentId;
    if (target == null) return;
    (this.position(target) as ValueNotifier<Duration>).value = position;
    if (target == _currentId) await _backend?.seek(position);
  }

  /// Playback rate for every message, for example 1, 1.5 or 2.
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
    await _backend?.setSpeed(speed);
  }

  /// Stops playback and releases the player; the next [play] opens a new
  /// one.
  Future<void> stop() async {
    await _release();
    notifyListeners();
  }

  Future<void> _release() async {
    final backend = _backend;
    _backend = null;
    _currentId = null;
    _playing = false;
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    for (final s in subscriptions) {
      await s.cancel();
    }
    await backend?.dispose();
  }

  @override
  void dispose() {
    unawaited(_release());
    for (final n in _positions.values) {
      n.dispose();
    }
    for (final n in _durations.values) {
      n.dispose();
    }
    super.dispose();
  }

  AudioBackend _ensureBackend() {
    final existing = _backend;
    if (existing != null) return existing;
    final backend = _backend = _createBackend();
    _subscriptions
      ..add(
        backend.positions.listen((p) {
          final id = _currentId;
          if (id != null) (position(id) as ValueNotifier<Duration>).value = p;
        }),
      )
      ..add(
        backend.durations.listen((d) {
          final id = _currentId;
          if (id != null && d > Duration.zero) {
            (duration(id) as ValueNotifier<Duration?>).value = d;
          }
        }),
      )
      ..add(
        backend.completions.listen((_) {
          final id = _currentId;
          if (id != null) {
            (position(id) as ValueNotifier<Duration>).value = Duration.zero;
          }
          _playing = false;
          _currentId = null;
          notifyListeners();
        }),
      );
    return backend;
  }
}

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
