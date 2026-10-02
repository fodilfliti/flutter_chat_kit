import 'package:flutter/foundation.dart';
import 'package:flutter_chat_pro/src/config/chat_strings.dart';
import 'package:intl/intl.dart';

/// Formats [time] (local) as a clock time, for example `3:04 PM`.
typedef TimeFormatter = String Function(DateTime time, String? locale);

/// Formats a local [date] relative to [now]: separators, inbox times,
/// last seen.
typedef RelativeDateFormatter =
    String Function(
      DateTime date,
      DateTime now,
      ChatStrings strings,
      String? locale,
    );

/// How dates, durations and sizes are shown. Every formatter can be
/// replaced; defaults use `intl` with the given locale.
///
/// All inputs are converted to local time before formatting. A locale that
/// `intl` has no data for falls back to its default (`en_US`), so call
/// `initializeDateFormatting` (or use `flutter_localizations`) for others.
@immutable
class ChatFormatters {
  const ChatFormatters({
    this.time,
    this.dateSeparator,
    this.roomTime,
    this.lastSeen,
    this.duration,
    this.fileSize,
  });

  final TimeFormatter? time;

  /// Day header in the message list.
  final RelativeDateFormatter? dateSeparator;

  /// Trailing time of an inbox row.
  final RelativeDateFormatter? roomTime;

  /// The `when` part of `ChatStrings.lastSeen`.
  final RelativeDateFormatter? lastSeen;

  /// Voice and video lengths.
  final String Function(Duration duration)? duration;
  final String Function(int bytes)? fileSize;

  String formatTime(DateTime time, {String? locale}) {
    final local = time.toLocal();
    return this.time?.call(local, locale) ??
        DateFormat.jm(_locale(locale)).format(local);
  }

  /// `Today`, `Yesterday`, weekday within a week, then `Sep 3` / `Sep 3,
  /// 2025`.
  String formatDateSeparator(
    DateTime date,
    ChatStrings strings, {
    DateTime? now,
    String? locale,
  }) {
    final local = date.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final custom = dateSeparator;
    if (custom != null) return custom(local, current, strings, locale);
    final l = _locale(locale);
    final days = _daysBetween(local, current);
    if (days == 0) return strings.today;
    if (days == 1) return strings.yesterday;
    if (days > 1 && days < 7) return DateFormat.EEEE(l).format(local);
    if (local.year == current.year) return DateFormat.MMMd(l).format(local);
    return DateFormat.yMMMd(l).format(local);
  }

  /// Time today, `Yesterday`, short weekday within a week, then a short
  /// date.
  String formatRoomTime(
    DateTime date,
    ChatStrings strings, {
    DateTime? now,
    String? locale,
  }) {
    final local = date.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final custom = roomTime;
    if (custom != null) return custom(local, current, strings, locale);
    final l = _locale(locale);
    final days = _daysBetween(local, current);
    if (days <= 0) return formatTime(local, locale: locale);
    if (days == 1) return strings.yesterday;
    if (days < 7) return DateFormat.E(l).format(local);
    if (local.year == current.year) return DateFormat.MMMd(l).format(local);
    return DateFormat.yMd(l).format(local);
  }

  /// Full "last seen ..." line.
  String formatLastSeen(
    DateTime lastSeenAt,
    ChatStrings strings, {
    DateTime? now,
    String? locale,
  }) {
    final local = lastSeenAt.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final when =
        lastSeen?.call(local, current, strings, locale) ??
        formatRoomTime(local, strings, now: current, locale: locale);
    return strings.lastSeen(when);
  }

  /// `0:42`, `12:05`, `1:02:03`.
  String formatDuration(Duration value) {
    final custom = duration;
    if (custom != null) return custom(value);
    final total = value.isNegative ? 0 : value.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  /// `512 B`, `1.2 MB` (base 1024, one decimal, trailing `.0` dropped).
  String formatFileSize(int bytes) {
    final custom = fileSize;
    if (custom != null) return custom(bytes);
    if (bytes < 1024) return '${bytes < 0 ? 0 : bytes} B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value.toStringAsFixed(1);
    final trimmed = text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
    return '$trimmed ${units[unit]}';
  }

  static String? _locale(String? locale) {
    if (locale == null) return null;
    // localeExists throws until initializeDateFormatting has run.
    try {
      return DateFormat.localeExists(locale) ? locale : null;
    } on Exception {
      return null;
    }
  }

  /// Calendar days from [a] to [b]; DST-safe.
  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime.utc(a.year, a.month, a.day);
    final db = DateTime.utc(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }
}
