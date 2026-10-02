/// Files, app directories and image providers.
///
/// Native and dart2js builds get `dart:io`, `path_provider` and
/// `cached_network_image`. dart2wasm builds have no file system and get
/// stand-ins instead, which keeps the library WebAssembly-compatible.
library;

export 'io_native.dart'
    if (dart.library.html) 'io_native.dart'
    if (dart.library.js_interop) 'io_wasm.dart';
