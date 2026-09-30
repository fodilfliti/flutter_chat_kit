import 'package:collection/collection.dart';

/// Deep equality for model collections (lists, maps, sets).
const deepEquality = DeepCollectionEquality();

/// Reads ISO-8601 strings, epoch milliseconds, or [DateTime]; returns UTC.
DateTime? readDate(Object? value) {
  return switch (value) {
    null => null,
    final DateTime date => date.toUtc(),
    final int millis => DateTime.fromMillisecondsSinceEpoch(
      millis,
      isUtc: true,
    ),
    final num millis => DateTime.fromMillisecondsSinceEpoch(
      millis.toInt(),
      isUtc: true,
    ),
    final String text => DateTime.parse(text).toUtc(),
    _ => throw FormatException('Unsupported date value: $value'),
  };
}

DateTime readRequiredDate(Map<String, Object?> json, String key) {
  return readDate(json[key]) ?? (throw FormatException('Missing "$key"'));
}

String? writeDate(DateTime? value) => value?.toUtc().toIso8601String();

String readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) throw FormatException('Missing "$key"');
  return value is String ? value : value.toString();
}

String? readOptionalString(Object? value) {
  if (value == null) return null;
  return value is String ? value : value.toString();
}

int? readInt(Object? value) {
  return switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

bool readBool(Object? value, {bool fallback = false}) {
  return switch (value) {
    final bool flag => flag,
    final num number => number != 0,
    final String text => text == 'true' || text == '1',
    _ => fallback,
  };
}

Duration? readDuration(Object? value) {
  final millis = readInt(value);
  return millis == null ? null : Duration(milliseconds: millis);
}

Map<String, Object?> readMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final e in value.entries) e.key.toString(): e.value};
}

List<Map<String, Object?>> readMapList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) readMap(item)];
}

List<double> readDoubleList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is num) item.toDouble(),
  ];
}

/// A list (or a single string) as a set of strings; empty otherwise.
Set<String> readStringSet(Object? value) {
  return switch (value) {
    final List<Object?> list => {
      for (final item in list)
        if (item != null) item.toString(),
    },
    final String single when single.isNotEmpty => {single},
    _ => const {},
  };
}

Map<String, Set<String>> readReactions(Object? value) {
  final raw = readMap(value);
  return {
    for (final e in raw.entries)
      if (e.value is List)
        e.key: {for (final id in e.value! as List) id.toString()},
  };
}

Map<String, List<String>> writeReactions(Map<String, Set<String>> value) {
  return {for (final e in value.entries) e.key: e.value.toList()..sort()};
}

/// Copies [json] without null values, so encoded payloads stay small.
Map<String, Object?> withoutNulls(Map<String, Object?> json) {
  return {
    for (final e in json.entries)
      if (e.value != null) e.key: e.value,
  };
}
