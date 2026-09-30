# T10 — Media and voice

## Goal

Images, video, voice notes and their players/recorder, built for smooth scrolling (no layout jumps, no list rebuilds for progress).

## Read first

- [../decisions.md](../decisions.md) D8; [../invariants.md](../invariants.md) (UI)
- valizex `LazyChatImage.dart`, `ConversationMediaGallery.dart`, `VideoMessageBubble.dart`, `AudioMessageBubble.dart`, `VoiceRecordingDialog.dart`, `service/voice_message_service.dart`

## Depends on

T09.

## Deliverables

```text
lib/src/widgets/media/chat_image.dart             local file while uploading, else CachedNetworkImage; memCacheWidth by DPR; Hero
lib/src/widgets/messages/image_message_view.dart  1 / 2 / 3 / 4+ grid ("+N"), aspect ratio reserved, progress overlay
lib/src/widgets/messages/video_message_view.dart  thumbnail + duration + play; opens viewer
lib/src/widgets/messages/audio_message_view.dart  play/pause, waveform bars (played portion colored), seek by drag, speed 1x/1.5x/2x
lib/src/widgets/media/media_viewer.dart           PageView over room media, InteractiveViewer zoom, video page, swipe-down dismiss
lib/src/controllers/audio_player_hub.dart         single AudioPlayer; current id; position/duration ValueListenables
lib/src/controllers/voice_recorder_controller.dart  record: idle, recording, locked, review; amplitude samples -> waveform
lib/src/media/waveform.dart                        downsample amplitudes to N bars
test/media/*_test.dart
```

## Public API

```dart
class AudioPlayerHub extends ChangeNotifier {
  String? get currentId;
  ValueListenable<Duration> position(String id); ValueListenable<Duration?> duration(String id);
  Future<void> play(String id, {String? url, String? localPath});  // pauses any other
  Future<void> pause(); Future<void> seek(Duration d); Future<void> setSpeed(double s);
}

enum RecorderState { idle, recording, locked, review }
class VoiceRecorderController extends ChangeNotifier {
  RecorderState get state; Duration get elapsed; List<double> get amplitudes;
  Future<bool> start();      // false if permission denied
  void lock(); Future<void> cancel(); Future<VoiceRecording?> stop(); // null if < config.minVoiceDuration
}
class VoiceRecording { final String path; final Duration duration; final List<double> waveform; }
```

`ChatKit` owns one `AudioPlayerHub` (disposed on `close`).

## Done when

- [ ] Image grid lays out at final size before the image loads (test with a never-completing image provider)
- [ ] Upload progress overlay updates without rebuilding siblings (test via build counter)
- [ ] Starting a second voice message pauses the first
- [ ] Recorder: < 1 s discarded; cancel deletes the temp file; amplitude produces a 40-bar waveform
- [ ] Viewer opens at the tapped item, swipes through all room media, zooms

## Do not

- Create one `AudioPlayer` per bubble
- Generate video thumbnails on device (use `thumbnailUrl`; fall back to a placeholder)
- Auto-save media to the gallery (app concern)
