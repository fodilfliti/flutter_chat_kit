import 'package:flutter_test/flutter_test.dart';

/// Alternates real time (the database) and frames until [until] holds.
Future<void> settle(WidgetTester tester, bool Function() until) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (until()) return;
  }
  fail('condition not reached');
}

bool shows(String text) => find.text(text).evaluate().isNotEmpty;
