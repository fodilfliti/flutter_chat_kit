import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const f = ChatFormatters();
  const strings = ChatStrings();
  // Wednesday.
  final now = DateTime(2026, 9, 30, 15);

  group('date separator', () {
    String sep(DateTime d) =>
        f.formatDateSeparator(d, strings, now: now, locale: 'en_US');

    test('today and yesterday use strings', () {
      expect(sep(DateTime(2026, 9, 30, 0, 5)), 'Today');
      expect(sep(DateTime(2026, 9, 29, 23, 59)), 'Yesterday');
    });

    test('weekday within a week, then date', () {
      expect(sep(DateTime(2026, 9, 26, 9)), 'Saturday');
      expect(sep(DateTime(2026, 9, 3, 9)), 'Sep 3');
      expect(sep(DateTime(2025, 9, 3, 9)), 'Sep 3, 2025');
    });

    test('custom strings and override win', () {
      expect(
        f.formatDateSeparator(
          DateTime(2026, 9, 30),
          const ChatStrings(today: "Aujourd'hui"),
          now: now,
        ),
        "Aujourd'hui",
      );
      final custom = ChatFormatters(
        dateSeparator: (date, now, strings, locale) => 'D${date.day}',
      );
      expect(
        custom.formatDateSeparator(DateTime(2026, 9), strings, now: now),
        'D1',
      );
    });
  });

  test('room time: clock today, Yesterday, weekday, date', () {
    String rt(DateTime d) =>
        f.formatRoomTime(d, strings, now: now, locale: 'en_US');
    expect(rt(DateTime(2026, 9, 30, 9, 4)), '9:04\u202fAM');
    expect(rt(DateTime(2026, 9, 29, 9)), 'Yesterday');
    expect(rt(DateTime(2026, 9, 26, 9)), 'Sat');
    expect(rt(DateTime(2026, 1, 2)), 'Jan 2');
    expect(rt(DateTime(2025, 1, 2)), '1/2/2025');
  });

  test('last seen wraps the room time', () {
    expect(
      f.formatLastSeen(DateTime(2026, 9, 29, 8), strings, now: now),
      'last seen Yesterday',
    );
  });

  test('unknown locale falls back instead of throwing', () {
    expect(
      f.formatDateSeparator(
        DateTime(2026, 9, 26),
        strings,
        now: now,
        locale: 'xx_YY',
      ),
      'Saturday',
    );
  });

  test('duration', () {
    expect(f.formatDuration(const Duration(seconds: 42)), '0:42');
    expect(f.formatDuration(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(
      f.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(f.formatDuration(const Duration(seconds: -3)), '0:00');
  });

  test('file size', () {
    expect(f.formatFileSize(512), '512 B');
    expect(f.formatFileSize(1024), '1 KB');
    expect(f.formatFileSize((1.2 * 1024 * 1024).round()), '1.2 MB');
    expect(f.formatFileSize(3 * 1024 * 1024 * 1024), '3 GB');
  });
}
