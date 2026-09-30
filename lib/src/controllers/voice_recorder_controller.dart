import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_kit/src/media/waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// The platform recorder behind [VoiceRecorderController]; replaced in
/// tests.
abstract interface class RecorderBackend {
  Future<bool> hasPermission();
  Future<void> start(String path);

  /// Returns the file path.
  Future<String?> stop();

  /// Levels in dBFS (about -60 quiet .. 0 loud).
  Stream<double> amplitudes(Duration interval);
  Future<void> dispose();
}

enum RecorderState {
  idle,
  recording,

  /// Recording hands-free (the user slid to lock).
  locked,

  /// Stopped and kept for listening before sending.
  review,
}

/// A finished voice note.
@immutable
class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  final String path;
  final Duration duration;

  /// Bars (0..1) for the bubble; see [downsampleWaveform].
  final List<double> waveform;
}

/// Records a voice note: permission, a temp file, the elapsed time and the
/// amplitude samples that become its waveform.
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({
    this.minDuration = const Duration(seconds: 1),
    this.waveformBars = 40,
    RecorderBackend? backend,
    Future<Directory> Function()? tempDirectory,
    DateTime Function()? clock,
  }) : _backend = backend ?? RecordBackend(),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  /// Shorter recordings are discarded by [stop].
  final Duration minDuration;
  final int waveformBars;
  final RecorderBackend _backend;
  final Future<Directory> Function() _tempDirectory;
  final DateTime Function() _clock;

  static const _sampleInterval = Duration(milliseconds: 100);

  RecorderState _state = RecorderState.idle;
  final _amplitudes = <double>[];
  StreamSubscription<double>? _levels;
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _path;
  VoiceRecording? _recording;
  bool _disposed = false;

  RecorderState get state => _state;

  bool get isRecording =>
      _state == RecorderState.recording || _state == RecorderState.locked;
  Duration get elapsed => _elapsed;

  /// Levels (0..1) sampled every 100 ms since [start].
  List<double> get amplitudes => List.unmodifiable(_amplitudes);

  /// The kept recording while in [RecorderState.review].
  VoiceRecording? get recording => _recording;

  /// Starts recording to a temp file. Returns false when the microphone
  /// permission is denied.
  Future<bool> start() async {
    if (_state != RecorderState.idle) return isRecording;
    if (!await _backend.hasPermission()) return false;
    final dir = await _tempDirectory();
    final path = p.join(dir.path, 'voice_${const Uuid().v4()}.m4a');
    await _backend.start(path);
    _path = path;
    _amplitudes.clear();
    _startedAt = _clock();
    _elapsed = Duration.zero;
    _levels = _backend
        .amplitudes(_sampleInterval)
        .listen((db) => _amplitudes.add(normalizeDecibels(db)));
    _ticker = Timer.periodic(_sampleInterval, (_) => _tick());
    _set(RecorderState.recording);
    return true;
  }

  /// Keeps recording without holding the button.
  void lock() {
    if (_state == RecorderState.recording) _set(RecorderState.locked);
  }

  /// Stops and deletes the recording, in any state.
  Future<void> cancel() async {
    final path = _path ?? _recording?.path;
    if (isRecording) await _finish();
    _recording = null;
    _path = null;
    await _delete(path);
    _set(RecorderState.idle);
  }

  /// Stops recording. Returns null (and deletes the file) when shorter than
  /// [minDuration]. With [review] the recording is kept in
  /// [RecorderState.review] until [reset] or [cancel]; otherwise the state
  /// returns to idle and the caller owns the file.
  Future<VoiceRecording?> stop({bool review = false}) async {
    if (!isRecording) return _recording;
    final path = await _finish();
    _path = null;
    if (path == null || _elapsed < minDuration) {
      await _delete(path);
      _set(RecorderState.idle);
      return null;
    }
    final recording = VoiceRecording(
      path: path,
      duration: _elapsed,
      waveform: downsampleWaveform(_amplitudes, bars: waveformBars),
    );
    if (review) {
      _recording = recording;
      _set(RecorderState.review);
    } else {
      _set(RecorderState.idle);
    }
    return recording;
  }

  /// Leaves review without deleting the file (for example after sending).
  void reset() {
    _recording = null;
    _set(RecorderState.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(_levels?.cancel());
    final path = _path;
    if (isRecording) {
      unawaited(
        _backend.stop().then((_) => _delete(path), onError: (Object _) {}),
      );
    }
    unawaited(_backend.dispose());
    super.dispose();
  }

  void _tick() {
    final started = _startedAt;
    if (started == null) return;
    _elapsed = _clock().difference(started);
    notifyListeners();
  }

  Future<String?> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    _tick();
    _startedAt = null;
    await _levels?.cancel();
    _levels = null;
    final stopped = await _backend.stop();
    return stopped ?? _path;
  }

  Future<void> _delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  void _set(RecorderState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }
}

/// [RecorderBackend] on `record` (AAC in an `.m4a` file). The platform
/// recorder is created on first use, so idle composers hold none.
class RecordBackend implements RecorderBackend {
  AudioRecorder? _instance;

  AudioRecorder get _recorder => _instance ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) =>
      _recorder.start(const RecordConfig(numChannels: 1), path: path);

  @override
  Future<String?> stop() async => await _instance?.stop();

  @override
  Stream<double> amplitudes(Duration interval) =>
      _recorder.onAmplitudeChanged(interval).map((a) => a.current);

  @override
  Future<void> dispose() async => await _instance?.dispose();
}
