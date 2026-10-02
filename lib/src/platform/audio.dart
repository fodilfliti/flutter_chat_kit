/// The default voice note player.
///
/// Native and dart2js builds play through `audioplayers`. dart2wasm builds
/// use an HTML audio element instead, which keeps the library
/// WebAssembly-compatible.
library;

export 'audio_native.dart'
    if (dart.library.html) 'audio_native.dart'
    if (dart.library.js_interop) 'audio_wasm.dart';
