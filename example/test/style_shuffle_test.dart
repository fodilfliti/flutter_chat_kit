import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_chat_pro_example/style/style_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shuffle walks through every preset, keeping scale', () {
    final style = StyleSettings(random: Random(1))
      ..zoom = 1.2
      ..textScale = 1.1;
    addTearDown(style.dispose);
    final seen = <ChatPreset>[];
    final looks = <(Color, bool, double)>{};
    for (var i = 0; i < ChatPreset.values.length * 2; i++) {
      style.shuffle();
      seen.add(style.preset);
      looks.add((style.seed, style.dark, style.bubbleRadius));
      if (style.preset.seedColor case final brand?) {
        expect(style.seed, brand);
      }
    }
    expect(
      seen.take(ChatPreset.values.length).toSet(),
      ChatPreset.values.toSet(),
    );
    expect(seen.first, ChatPreset.values[1]);
    // Colors, dark mode and shapes really change along the way.
    expect(looks.length, greaterThan(ChatPreset.values.length));
    expect(looks.map((look) => look.$2).toSet(), {true, false});
    expect(style.zoom, 1.2);
    expect(style.textScale, 1.1);
  });

  testWidgets('auto shuffle changes the look on a timer until reset', (
    tester,
  ) async {
    final style = StyleSettings(random: Random(2));
    addTearDown(style.dispose);
    var changes = 0;
    style
      ..addListener(() => changes++)
      ..autoShuffle = true;
    expect(style.autoShuffle, isTrue);
    expect(style.preset, ChatPreset.values[1]);

    await tester.pump(StyleSettings.shuffleEvery * 3);
    expect(style.preset, ChatPreset.values[4]);
    expect(changes, 4);

    style.autoShuffle = false;
    await tester.pump(StyleSettings.shuffleEvery * 3);
    expect(style.preset, ChatPreset.values[4]);

    style
      ..autoShuffle = true
      ..resetAll();
    expect(style.autoShuffle, isFalse);
    expect(style.preset, ChatPreset.classic);
    await tester.pump(StyleSettings.shuffleEvery * 3);
    expect(style.preset, ChatPreset.classic);
  });
}
