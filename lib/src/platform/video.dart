/// The video player of the media viewer and the video probe of the pickers.
///
/// Native and dart2js builds use `video_player`. dart2wasm builds use an
/// HTML video element with the same API subset instead, which keeps the
/// library WebAssembly-compatible.
library;

export 'package:video_player/video_player.dart'
    if (dart.library.html) 'package:video_player/video_player.dart'
    if (dart.library.js_interop) 'video_wasm.dart'
    show
        VideoPlayer,
        VideoPlayerController,
        VideoPlayerValue,
        VideoProgressColors,
        VideoProgressIndicator;
