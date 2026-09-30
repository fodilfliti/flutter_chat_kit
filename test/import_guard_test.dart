import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The kit is backend-agnostic and never localizes (spec/invariants.md).
void main() {
  const banned = [
    'package:firebase_',
    'package:cloud_firestore',
    'package:supabase',
    'package:dio',
    'riverpod',
    'package:slang',
    'package:easy_localization',
    '.tr(',
  ];

  test('lib/ does not import backend SDKs, Riverpod, or localization', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final pattern in banned) {
          if (line.contains(pattern)) {
            offenders.add('${file.path}:${i + 1}: $pattern');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
