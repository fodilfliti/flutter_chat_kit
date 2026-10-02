import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Stands in for the `dart:io` file in WebAssembly builds, which have no
/// file system: nothing exists and every operation throws.
class File {
  /// A file at [path].
  File(this.path);

  /// The path given to the constructor.
  final String path;

  /// Always false.
  bool existsSync() => false;

  /// Throws [UnsupportedError].
  int lengthSync() => _unsupported();

  /// Throws [UnsupportedError].
  Future<int> length() => _unsupported();

  /// Throws [UnsupportedError].
  Future<Uint8List> readAsBytes() => _unsupported();

  /// Throws [UnsupportedError].
  Future<File> copy(String newPath) => _unsupported();

  /// Throws [UnsupportedError].
  Future<File> rename(String newPath) => _unsupported();

  /// Throws [UnsupportedError].
  Future<File> delete() => _unsupported();

  /// Throws [UnsupportedError].
  IOSink openWrite() => _unsupported();
}

/// Stands in for the `dart:io` sink in WebAssembly builds.
abstract interface class IOSink {
  /// Writes [data].
  void add(List<int> data);

  /// Flushes and closes the sink.
  Future<void> close();
}

/// Stands in for the `dart:io` directory in WebAssembly builds: nothing
/// exists and every operation throws.
class Directory {
  /// A directory at [path].
  Directory(this.path);

  /// The path given to the constructor.
  final String path;

  /// Always false.
  bool existsSync() => false;

  /// Throws [UnsupportedError].
  Future<Directory> create({bool recursive = false}) => _unsupported();

  /// Throws [UnsupportedError].
  Future<Directory> delete({bool recursive = false}) => _unsupported();
}

/// Stands in for the `dart:io` exception in WebAssembly builds.
class FileSystemException implements Exception {
  /// An exception with [message].
  const FileSystemException([this.message = '']);

  /// What went wrong.
  final String message;
}

/// Throws [UnsupportedError].
Future<Directory> getApplicationSupportDirectory() => _unsupported();

/// Throws [UnsupportedError].
Future<Directory> getTemporaryDirectory() => _unsupported();

/// The image at [path], which on the web is a `blob:` URL.
ImageProvider fileImage(String path) => NetworkImage(path);

/// The image at [url]; the browser caches it.
ImageProvider networkImage(String url) => NetworkImage(url);

Never _unsupported() =>
    throw UnsupportedError('WebAssembly builds have no file system');
