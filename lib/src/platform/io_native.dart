import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

export 'dart:io' show Directory, File, FileSystemException;
export 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory, getTemporaryDirectory;

/// The image in the file at [path].
ImageProvider fileImage(String path) => FileImage(File(path));

/// The image at [url], cached on disk. A failed load only reaches the
/// image's `errorBuilder`, not the error log.
ImageProvider networkImage(String url) =>
    CachedNetworkImageProvider(url, errorListener: _ignore);

void _ignore(Object _) {}
