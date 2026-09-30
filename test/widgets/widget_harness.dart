import 'package:flutter_test/flutter_test.dart';

/// Alternates real time (for the in-memory database) and frames until
/// [until] holds, or for a few rounds when null.
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (until == null ? i >= 5 : until()) return;
  }
  if (until != null) fail('condition not reached');
}

/// Runs started scroll animations to their end.
Future<void> finishAnimations(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }
}

/// Settles until [future] completes and returns its value.
Future<T> drive<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  (Object, StackTrace)? error;
  future
      .then(
        (v) {
          value = v;
          done = true;
        },
        onError: (Object e, StackTrace s) {
          error = (e, s);
          done = true;
        },
      )
      .ignore();
  await settle(tester, until: () => done);
  if (error case (final e, final s)) Error.throwWithStackTrace(e, s);
  return value;
}
