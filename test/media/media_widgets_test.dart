import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cache/memory_cache.dart';
import '../controllers/harness.dart';

/// A store whose lookups and downloads never finish, so widgets stay in
/// their loading state.
class _HangingStore extends ChatMediaStore {
  _HangingStore() : super(userId: 'me', cache: memoryCache());

  final saves = <String>[];

  @override
  Future<File?> file(String remoteUrl) => Completer<File?>().future;

  @override
  Future<File> fetch(
    String remoteUrl, {
    void Function(double fraction)? onProgress,
  }) => Completer<File>().future;

  @override
  Future<bool> save(String remoteUrl, {String? name, String? mimeType}) async {
    saves.add(remoteUrl);
    return true;
  }
}

/// Nothing is stored; downloads are recorded and never finish.
class _NotStoredStore extends _HangingStore {
  final fetches = <String>[];

  @override
  Future<File?> file(String remoteUrl) async => null;

  @override
  Future<File> fetch(
    String remoteUrl, {
    void Function(double fraction)? onProgress,
  }) {
    fetches.add(remoteUrl);
    return Completer<File>().future;
  }
}

Attachment image(int i, {int width = 400, int height = 300}) => Attachment(
  mimeType: 'image/jpeg',
  remoteUrl: 'https://cdn.test/$i.jpg',
  width: width,
  height: height,
);

Future<void> show(
  WidgetTester tester,
  Widget child, {
  ChatMediaStore? store,
  AudioPlayerHub? audio,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatMediaScope(
          store: store,
          audio: audio,
          child: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    ),
  );
}

void main() {
  group('ImageMessageView', () {
    testWidgets('has its final size before any image loads', (tester) async {
      final store = _HangingStore();
      await show(
        tester,
        ImageMessageView(images: [image(1, height: 200)]),
        store: store,
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(ImageMessageView)),
        const Size(300, 300 / 1.8),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await show(
        tester,
        ImageMessageView(images: [image(1), image(2), image(3)]),
        store: store,
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(ImageMessageView)),
        const Size(300, 300),
      );

      await show(
        tester,
        ImageMessageView(images: [image(1), image(2)]),
        store: store,
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(ImageMessageView)),
        const Size(300, 150),
      );
    });

    testWidgets('more than four images show +N on the last cell', (
      tester,
    ) async {
      final tapped = <int>[];
      await show(
        tester,
        ImageMessageView(
          images: [for (var i = 0; i < 6; i++) image(i)],
          onTap: tapped.add,
          cellBuilder: (context, a, i) =>
              ColoredBox(key: ValueKey('cell$i'), color: Colors.grey),
        ),
      );
      expect(find.text('+2'), findsOneWidget);
      expect(find.byKey(const ValueKey('cell4')), findsNothing);
      await tester.tapAt(tester.getCenter(find.text('+2')));
      expect(tapped, [3]);
    });

    testWidgets('upload progress does not rebuild the cells', (tester) async {
      var builds = 0;
      final progress = ValueNotifier<double?>(0.2);
      await show(
        tester,
        ImageMessageView(
          images: [image(1), image(2)],
          progress: progress,
          cellBuilder: (context, a, i) {
            builds++;
            return const ColoredBox(color: Colors.grey);
          },
        ),
      );
      expect(builds, 2);
      progress.value = 0.6;
      await tester.pump();
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.6);
      progress.value = null;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(builds, 2);
    });
  });

  testWidgets('images wait for a tap when auto-download is off', (
    tester,
  ) async {
    final store = _NotStoredStore();
    await show(
      tester,
      SizedBox.square(
        dimension: 200,
        child: ChatImage(
          attachment: image(1),
          store: store,
          autoDownload: false,
        ),
      ),
      store: store,
    );
    await tester.pump();
    expect(store.fetches, isEmpty);
    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    expect(store.fetches, ['https://cdn.test/1.jpg']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a video shows its poster placeholder, play and duration', (
    tester,
  ) async {
    var taps = 0;
    await show(
      tester,
      VideoMessageView(
        video: const Attachment(
          mimeType: 'video/mp4',
          remoteUrl: 'https://cdn.test/v.mp4',
          duration: Duration(seconds: 75),
          width: 1920,
          height: 1080,
        ),
        onTap: () => taps++,
      ),
    );
    expect(find.text('1:15'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    expect(tester.getSize(find.byType(VideoMessageView)).width, 300);
    await tester.tap(find.byType(VideoMessageView));
    expect(taps, 1);
  });

  testWidgets('a video being compressed says so', (tester) async {
    final progress = ValueNotifier<double?>(Outbox.compressing);
    addTearDown(progress.dispose);
    await show(
      tester,
      VideoMessageView(
        video: const Attachment(mimeType: 'video/mp4', localPath: 'v.mp4'),
        progress: progress,
      ),
    );
    expect(find.text('Compressing'), findsOneWidget);

    progress.value = 0.5;
    await tester.pump();
    expect(find.text('Compressing'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a video being sent shows the poster made on the device', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('chat_poster_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final poster = File('${temp.path}/v.jpg')..writeAsBytesSync([0xFF, 0xD8]);
    await show(
      tester,
      VideoMessageView(
        video: Attachment(
          mimeType: 'video/mp4',
          localPath: '${temp.path}/v.mp4',
          thumbnailPath: poster.path,
          thumbnailUrl: 'https://cdn.test/v.jpg',
        ),
      ),
      store: _HangingStore(),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = (image.image as ResizeImage).imageProvider;
    expect(provider, isA<FileImage>());
    expect((provider as FileImage).file.path, poster.path);
  });

  group('MediaViewer', () {
    // The pages show endless spinners, so pumpAndSettle would never return.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<_HangingStore> open(WidgetTester tester) async {
      final store = _HangingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaViewer(
            items: [
              for (var i = 0; i < 3; i++) MediaItem(attachment: image(i)),
            ],
            initialIndex: 1,
            store: store,
          ),
        ),
      );
      await tester.pump();
      return store;
    }

    testWidgets('opens at the tapped item and swipes between items', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('2 of 3'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await frames(tester);
      expect(find.text('3 of 3'), findsOneWidget);
    });

    testWidgets('double tap zooms and locks paging', (tester) async {
      await open(tester);
      final center = tester.getCenter(find.byType(PageView));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(center);
      await frames(tester);
      final pages = tester.widget<PageView>(find.byType(PageView));
      expect(pages.physics, isA<NeverScrollableScrollPhysics>());

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await frames(tester);
      expect(find.text('2 of 3'), findsOneWidget);
    });

    testWidgets('save exports through the store and confirms', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byTooltip('Save'));
      await tester.pump();
      await tester.pump();
      expect(store.saves, ['https://cdn.test/1.jpg']);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('swiping down closes it', (tester) async {
      final store = _HangingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => MediaViewer.show(
                context,
                items: [MediaItem(attachment: image(0))],
                store: store,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MediaViewer), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(0, 300), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MediaViewer), findsNothing);
    });
  });

  group('AudioMessageView', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('chat_audio_'));
    tearDown(() => temp.deleteSync(recursive: true));

    testWidgets('plays the local file and cycles the speed', (tester) async {
      final file = File('${temp.path}/v.m4a')..writeAsStringSync('audio');
      final backend = _FakeAudio();
      final hub = AudioPlayerHub(backend: () => backend);
      addTearDown(hub.dispose);
      final message = AudioMessage(
        id: 'a1',
        localId: 'a1',
        roomId: 'r1',
        authorId: 'me',
        createdAt: t0,
        audio: Attachment(mimeType: 'audio/mp4', localPath: file.path),
        duration: const Duration(seconds: 7),
        waveform: List.filled(40, 0.5),
      );
      await show(
        tester,
        AudioMessageView(
          message: message,
          color: Colors.black,
          metaStyle: const TextStyle(fontSize: 12),
        ),
        audio: hub,
      );
      expect(find.text('0:07'), findsOneWidget);
      expect(find.text('1x'), findsNothing);

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(backend.calls.first, 'play ${file.path}');
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.text('1x'));
      await tester.pump();
      expect(find.text('1.5x'), findsOneWidget);
      await tester.tap(find.text('1.5x'));
      await tester.pump();
      expect(find.text('2x'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(backend.calls.last, 'pause');
    });
  });

  testWidgets('a captioned image message shows the caption and the grid', (
    tester,
  ) async {
    final message = ImageMessage(
      id: 'i1',
      localId: 'i1',
      roomId: 'r1',
      authorId: 'u2',
      createdAt: t0,
      images: [image(1)],
      caption: 'Nice view',
    );
    await show(
      tester,
      MessageContent(
        message: MessageContext(
          message: message,
          currentUserId: 'me',
          isMine: false,
          groupPosition: GroupPosition.single,
          index: 0,
          uploadProgress: ValueNotifier<double?>(null),
        ),
      ),
      store: _HangingStore(),
    );
    await tester.pump();
    expect(find.text('Nice view'), findsOneWidget);
    expect(find.byType(ImageMessageView), findsOneWidget);
    expect(
      tester.getSize(find.byType(ImageMessageView)).width,
      closeTo(294, 1),
    );
  });
}

class _FakeAudio implements AudioBackend {
  final calls = <String>[];

  @override
  Stream<Duration> get positions => const Stream.empty();

  @override
  Stream<Duration> get durations => const Stream.empty();

  @override
  Stream<void> get completions => const Stream.empty();

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
  Future<void> dispose() async {}
}
