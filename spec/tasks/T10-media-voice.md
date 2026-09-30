# T10 — Media and voice

## Goal

Images, video, voice notes and their players/recorder, built for smooth scrolling (no layout jumps, no list rebuilds for progress).

## Read first

- [../decisions.md](../decisions.md) D8, D10, D11, D12; [../invariants.md](../invariants.md) (UI)
- valizex `LazyChatImage.dart`, `ConversationMediaGallery.dart`, `VideoMessageBubble.dart`, `AudioMessageBubble.dart`, `VoiceRecordingDialog.dart`, `service/voice_message_service.dart`

## Depends on

T09.

## Deliverables

```text
lib/src/media/chat_media_store.dart               D11: files on disk + Drift index, download (with progress), LRU size limit, clear
lib/src/cache/drift/tables.dart                   add MediaFiles table (remote_url PK, local_path, size, mime_type, last_access); schema migration
lib/src/widgets/media/chat_image.dart             local or stored file first, else download into the store (CachedNetworkImage only on web); memCacheWidth by DPR; Hero
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

```dart
class ChatMediaStore {
  Future<File?> file(String remoteUrl);                          // stored copy or null
  Future<File> fetch(String remoteUrl, {void Function(double)? onProgress}); // download once, then reuse
  Future<void> adopt(String localPath, String remoteUrl);         // own sent file: copy in, no download
  ValueListenable<double?> downloadProgress(String remoteUrl);
  Future<void> save(String remoteUrl, {String? name});           // FilePicker.saveFile unless ChatKit.onSaveMedia is set
  Future<void> trim({required int maxBytes}); Future<void> clear();
}
```

`ChatKit` owns one `AudioPlayerHub` and one `ChatMediaStore` (disposed on `close`; the store is cleared by `clearUserData`). The outbox calls `adopt` after each upload. `ChatConfig` gains `maxMediaCacheBytes` and `autoDownload` (images and audio by default; video and files on tap). Every label (save, download, open, failed) comes from `ChatStrings` (D12).

## Done when

- [x] Image grid lays out at final size before the image loads (test with a never-completing image provider)
- [x] Upload progress overlay updates without rebuilding siblings (test via build counter)
- [x] Starting a second voice message pauses the first
- [x] Recorder: < 1 s discarded; cancel deletes the temp file; amplitude produces a 40-bar waveform
- [x] Viewer opens at the tapped item, swipes through all room media, zooms
- [x] Media store: second view reads from disk (no request); own sent image never downloads; LRU trim respects the limit; `clearUserData` removes the files; save uses the override when given

## As built

- **Store.** Files live in `appSupport/flutter_chat_kit/media/<uuid v5 of userId>/`, named by the uuid v5 of the URL plus its extension. The Drift `media_files` table (schema v2, created by migration) holds the relative `fileName`, `size`, `mimeType` and `lastAccess`, indexed for LRU. Downloads stream to a `.part` file, then rename; concurrent fetches share one download. `peek` returns a file already resolved this session, so revisited bubbles show it on the first frame. On the web `isSupported` is false and widgets load URLs.
- **Kit.** `ChatKit(onSaveMedia:, mediaStore:, audio:)` exposes `media` and `audio`. The outbox's `onUploaded` hook calls `adopt`. `close` stops audio; `clearUserData` clears the files before the cache. `ChatConfig.maxMediaCacheBytes` defaults to 500 MB; `autoDownload` defaults to images and audio.
- **Scope.** `ChatMediaScope` (provided by `ChatMessageList`, falling back to `ChatKitScope`) gives media widgets the store, the hub and `autoDownload`. `MediaViewer` takes the store explicitly, since pushed routes do not see the list's scope.
- **Widgets.**
  - `ChatImage` loads the local file of a sending message, then the stored copy, then downloads (or shows a download button). It decodes at box width × DPR with `ResizeImage`.
  - `ImageMessageView` reserves its aspect ratio (a single image is clamped to 0.6–1.8). It takes `cellBuilder` and `heroTags`; upload progress lives in its own `ValueListenableBuilder`.
  - `VideoMessageView` shows only the `thumbnailUrl` poster.
  - `AudioMessageView` uses `WaveformPainter`, tap or drag to seek, and speed cycling. It plays from the local path or the store.
- **Bubble.** Images and videos use a 3 px bubble inset with clipping and no intrinsic sizing. Without a caption, the time sits on the media in a dark pill.
- **List.** By default, image and video taps open `MediaViewer` over the loaded room media (oldest first, with matching Hero tags from `MessageContent.heroTagFor`); file taps save through the store. Taps toggle selection while selecting.
- **Testability.** `AudioBackend` and `RecorderBackend` wrap `audioplayers` and `record`. `MediaViewer.videoControllerFactory` replaces `video_player` in tests.
- **Strings (D12).** New `ChatStrings` entries: `save`, `saved`, `download`, `downloadFailed`, `play`, `pause`, `close`, `playbackSpeed`, `moreMedia`, `mediaPosition`.

## Do not

- Create one `AudioPlayer` per bubble
- Generate video thumbnails on device (use `thumbnailUrl`; fall back to a placeholder)
- Auto-save media to the gallery (app concern; the explicit "Save" action is the kit's, D11)
- Add a package at anything but its latest version (D10)
