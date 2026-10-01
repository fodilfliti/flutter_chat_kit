import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_chat_kit_example/i18n/strings.g.dart';
import 'package:flutter_chat_kit_example/style/style_settings.dart';

/// App bar button that opens the live style sheet.
class StyleButton extends StatelessWidget {
  const StyleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.t.style.button,
      icon: const Icon(Icons.palette_outlined),
      onPressed: () => unawaited(showStyleSheet(context)),
    );
  }
}

/// Every change applies at once to the screen behind the sheet.
Future<void> showStyleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scroll) => _StyleSheet(scroll: scroll),
    ),
  );
}

const List<Color> _seeds = [
  Colors.teal,
  Color(0xFF25D366),
  Color(0xFF2AABEE),
  Colors.indigo,
  Colors.deepPurple,
  Colors.pink,
  Colors.deepOrange,
  Colors.brown,
  Colors.blueGrey,
];

class _StyleSheet extends StatelessWidget {
  const _StyleSheet({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final s = StyleScope.of(context);
    final t = context.t.style;
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.titleSmall;

    String presetName(ChatPreset preset) => switch (preset.name) {
      'classic' => t.presets.classic,
      'whatsApp' => t.presets.whatsApp,
      'telegram' => t.presets.telegram,
      'minimal' => t.presets.minimal,
      'cards' => t.presets.cards,
      final name => name,
    };

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: label?.copyWith(color: scheme.primary)),
    );

    Widget slider(
      String title,
      double value,
      double min,
      double max,
      ValueChanged<double> onChanged, {
      int? divisions,
      String Function(double)? format,
      bool enabled = true,
    }) {
      final text = format?.call(value) ?? value.toStringAsFixed(0);
      return ListTile(
        dense: true,
        enabled: enabled,
        title: Text('$title: $text'),
        subtitle: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          label: text,
          onChanged: enabled ? onChanged : null,
        ),
      );
    }

    Widget toggle(
      String title, {
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      dense: true,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );

    String times(double v) => 'Ã—${v.toStringAsFixed(2)}';

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        section(t.preset),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in ChatPreset.values)
                ChoiceChip(
                  label: Text(presetName(preset)),
                  selected: s.preset == preset,
                  onSelected: (_) => s.applyPreset(preset),
                ),
            ],
          ),
        ),
        section(t.colors),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _seeds)
                _Swatch(
                  color: color,
                  selected: s.seed.toARGB32() == color.toARGB32(),
                  onTap: () => s.seed = color,
                ),
            ],
          ),
        ),
        toggle(t.darkMode, value: s.dark, onChanged: (v) => s.dark = v),
        section(t.size),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ScreenScale>(
            segments: [
              ButtonSegment(value: ScreenScale.off, label: Text(t.design)),
              ButtonSegment(
                value: ScreenScale.byScreen,
                label: Text(t.byScreen),
              ),
              ButtonSegment(
                value: ScreenScale.scaleKit,
                label: Text(t.scaleKit),
              ),
            ],
            selected: {s.screen},
            onSelectionChanged: (v) => s.screen = v.first,
          ),
        ),
        slider(
          t.zoom,
          s.zoom,
          0.8,
          1.4,
          (v) => s.zoom = v,
          divisions: 12,
          format: times,
        ),
        slider(
          t.textSize,
          s.textScale,
          0.8,
          1.4,
          (v) => s.textScale = v,
          divisions: 12,
          format: times,
        ),
        section(t.messages),
        slider(
          t.messageFontSize,
          s.messageFontSize,
          12,
          22,
          (v) => s.messageFontSize = v,
        ),
        toggle(t.greyText, value: s.greyText, onChanged: (v) => s.greyText = v),
        slider(
          t.bubbleRadius,
          s.bubbleRadius,
          0,
          28,
          (v) => s.bubbleRadius = v,
        ),
        toggle(
          t.bubbleShadows,
          value: s.bubbleShadows,
          onChanged: (v) => s.bubbleShadows = v,
        ),
        toggle(
          t.bubbleBorder,
          value: s.bubbleBorder,
          onChanged: (v) => s.bubbleBorder = v,
        ),
        section(t.inbox),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ChatTiles>(
            segments: [
              ButtonSegment(value: ChatTiles.plain, label: Text(t.plain)),
              ButtonSegment(value: ChatTiles.divided, label: Text(t.lines)),
              ButtonSegment(value: ChatTiles.cards, label: Text(t.cards)),
            ],
            selected: {s.tiles},
            onSelectionChanged: (v) => s.tiles = v.first,
          ),
        ),
        slider(
          t.cardRadius,
          s.tileRadius,
          0,
          28,
          (v) => s.tileRadius = v,
          enabled: s.tiles == ChatTiles.cards,
        ),
        toggle(
          t.squareAvatars,
          value: s.squareAvatars,
          onChanged: (v) => s.squareAvatars = v,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: s.reset,
            icon: const Icon(Icons.restart_alt),
            label: Text(t.reset(name: presetName(s.preset))),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? ring : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
