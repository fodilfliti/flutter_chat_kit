import 'dart:async';
import 'dart:io';

import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('waveform', () {
    test('downsamples to the bar count with the peak normalized to 1', () {
      final samples = [for (var i = 0; i < 400; i++) (i % 10) / 20];
      final bars = downsampleWaveform(samples);
      expect(bars, hasLength(40));
      expect(bars.reduce((a, b) => a > b ? a : b), 1);
      expect(bars.every((b) => b >= 0 && b <= 1), isTrue);
    });

    test('short input is stretched; empty input is flat', () {
      expect(downsampleWaveform(const []), List.filled(40, 0));
      final stretched = downsampleWaveform(const [0.2, 0.4], bars: 4);
      expect(stretched, [0.5, 0.5, 1, 1]);
    });

    test('decibels map to 0..1', () {
      expect(normalizeDecibels(-60), 0);
      expect(normalizeDecibels(-120), 0);
      expect(normalizeDecibels(0), 1);
      expect(normalizeDecibels(-30), closeTo(0.5, 1e-9));
    });
  });

  group('AudioPlayerHub', () {
    late _FakeAudio backend;
    late AudioPlayerHub hub;

    setUp(() {
      backend = _FakeAudio();
      hub = AudioPlayerHub(backend: () => backend);
    });

    tearDown(() => hub.dispose());

    test('playing another message stops the first', () async {
      await hub.play('a', url: 'https://cdn.test/a.m4a');
      expect(hub.isPlayingId('a'), isTrue);
      await hub.play('b', localPath: '/tmp/b.m4a');
      expect(hub.isPlayingId('a'), isFalse);
      expect(hub.isPlayingId('b'), isTrue);
      expect(backend.calls, [
        'play https://cdn.test/a.m4a',
        'speed 1.0',
        'stop',
        'play /tmp/b.m4a',
        'speed 1.0',
      ]);
    });

    test('pause then play resumes the same message', () async {
      await hub.play('a', url: 'u');
      await hub.pause();
      expect(hub.isPlaying, isFalse);
      expect(hub.currentId, 'a');
      await hub.play('a', url: 'u');
      expect(backend.calls.last, 'resume');
      expect(hub.isPlayingId('a'), isTrue);
    });

    test('positions go to the current message; completion resets', () async {
      await hub.play('a', url: 'u');
      backend.positionEvents.add(const Duration(seconds: 3));
      backend.durationEvents.add(const Duration(seconds: 9));
      await pumpEventQueue();
      expect(hub.position('a').value, const Duration(seconds: 3));
      expect(hub.duration('a').value, const Duration(seconds: 9));
      expect(hub.position('b').value, Duration.zero);

      backend.completionEvents.add(null);
      await pumpEventQueue();
      expect(hub.isPlaying, isFalse);
      expect(hub.currentId, isNull);
      expect(hub.position('a').value, Duration.zero);
    });

    test('speed applies to the player', () async {
      await hub.play('a', url: 'u');
      await hub.setSpeed(1.5);
      expect(hub.speed, 1.5);
      expect(backend.calls.last, 'speed 1.5');
    });
  });

  group('VoiceRecorderController', () {
    late Directory temp;
    late _FakeRecorder backend;
    late DateTime now;
    late VoiceRecorderController recorder;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('chat_voice_');
      backend = _FakeRecorder();
      now = DateTime.utc(2026, 9, 30);
      recorder = VoiceRecorderController(
        backend: backend,
        tempDirectory: () async => temp,
        clock: () => now,
      );
    });

    tearDown(() {
      recorder.dispose();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('recordings under a second are discarded', () async {
      expect(await recorder.start(), isTrue);
      final path = backend.path!;
      expect(File(path).existsSync(), isTrue);
      now = now.add(const Duration(milliseconds: 600));
      expect(await recorder.stop(), isNull);
      expect(File(path).existsSync(), isFalse);
      expect(recorder.state, RecorderState.idle);
    });

    test('a long enough recording keeps its file and waveform', () async {
      await recorder.start();
      for (var i = 0; i < 30; i++) {
        backend.levels.add(-60 + i * 2.0);
      }
      await pumpEventQueue();
      now = now.add(const Duration(seconds: 3));
      final recording = await recorder.stop(review: true);
      expect(recording, isNotNull);
      expect(recording!.duration, const Duration(seconds: 3));
      expect(recording.waveform, hasLength(40));
      expect(recording.waveform.last, 1);
      expect(File(recording.path).existsSync(), isTrue);
      expect(recorder.state, RecorderState.review);
      recorder.reset();
      expect(File(recording.path).existsSync(), isTrue);
    });

    test('cancel deletes the file, also while locked', () async {
      await recorder.start();
      recorder.lock();
      expect(recorder.state, RecorderState.locked);
      final path = backend.path!;
      now = now.add(const Duration(seconds: 5));
      await recorder.cancel();
      expect(File(path).existsSync(), isFalse);
      expect(recorder.state, RecorderState.idle);
    });

    test('no permission, no recording', () async {
      backend.allowed = false;
      expect(await recorder.start(), isFalse);
      expect(recorder.state, RecorderState.idle);
      expect(backend.path, isNull);
    });
  });
}

class _FakeAudio implements AudioBackend {
  final calls = <String>[];
  final positionEvents = StreamController<Duration>.broadcast();
  final durationEvents = StreamController<Duration>.broadcast();
  final completionEvents = StreamController<void>.broadcast();

  @override
  Stream<Duration> get positions => positionEvents.stream;

  @override
  Stream<Duration> get durations => durationEvents.stream;

  @override
  Stream<void> get completions => completionEvents.stream;

  @override
  Future<void> play({String? url, String? localPath}) async =>
      calls.add('play ${localPath ?? url}');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async => calls.add('seek $position');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class _FakeRecorder implements RecorderBackend {
  bool allowed = true;
  String? path;
  final levels = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    this.path = path;
    File(path).writeAsStringSync('audio');
  }

  @override
  Future<String?> stop() async => path;

  @override
  Stream<double> amplitudes(Duration interval) => levels.stream;

  @override
  Future<void> dispose() async {}
}
