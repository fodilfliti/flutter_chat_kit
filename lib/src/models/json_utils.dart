import 'package:collection/collection.dart';

/// Deep equality for model collections (lists, maps, sets).
const deepEquality = DeepCollectionEquality();

/// Numbers below this are epoch seconds: as milliseconds they would be
/// before March 1973.
const epochSecondsLimit = 100000000000;

/// Reads ISO-8601 strings, epoch milliseconds or seconds, or [DateTime];
/// returns UTC.
DateTime? readDate(Object? value) {
  return switch (value) {
    null => null,
    final DateTime date => date.toUtc(),
    final num number => DateTime.fromMillisecondsSinceEpoch(
      number.abs() < epochSecondsLimit
          ? (number * 1000).round()
          : number.round(),
      isUtc: true,
    ),
    final String text => _parseDateText(text),
    _ => throw FormatException('Unsupported date value: $value'),
  };
}

DateTime _parseDateText(String text) {
  final number = num.tryParse(text);
  if (number != null) return readDate(number)!;
  return DateTime.parse(text).toUtc();
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

/// A list as is, a single non-null value as a one-item list, else empty.
List<Object?> readList(Object? value) {
  return switch (value) {
    null => const [],
    final List<Object?> list => list,
    _ => [value],
  };
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
