import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/wall_clock_watcher.dart';

/// Requested directly: "make current time respond immediately after a time
/// change in the system."
void main() {
  late DateTime wall;
  late int changes;
  late WallClockWatcher watcher;

  /// Moves the fake wall clock and the test's timers together, as real
  /// time would — one `checkEvery` tick at a time, so `now()` reads a
  /// freshly-advanced value on each tick instead of jumping to the end
  /// before any timers fire (which the watcher would wrongly read as the
  /// system clock jumping).
  Future<void> elapse(WidgetTester tester, Duration d) async {
    var remaining = d;
    while (remaining > Duration.zero) {
      final step = remaining < WallClockWatcher.checkEvery
          ? remaining
          : WallClockWatcher.checkEvery;
      wall = wall.add(step);
      await tester.pump(step);
      remaining -= step;
    }
  }

  setUp(() {
    changes = 0;
  });

  // flutter_test asserts no Timer is pending immediately after the test
  // body returns, BEFORE registered `addTearDown` callbacks run, so a
  // timer only cancelled there still trips that assertion. Disposing in a
  // `finally` (rather than as the test body's last line) is what still
  // disposes it — and so un-registers its `WidgetsBindingObserver` and
  // cancels its timers — when an `expect()` above throws, which would
  // otherwise leak that watcher's Timer/observer into the NEXT test.
  void startAt(DateTime t) {
    wall = t;
    watcher = WallClockWatcher(now: () => wall, onChange: () => changes++)
      ..start();
  }

  testWidgets('fires on the minute boundary, not a minute after starting', (
    tester,
  ) async {
    startAt(DateTime(2026, 10, 1, 12, 0, 50));
    try {
      await elapse(tester, const Duration(seconds: 9));
      expect(changes, 0, reason: 'a steady clock is not a jump');
      await elapse(tester, const Duration(seconds: 1));
      expect(changes, 1, reason: '12:01:00');
    } finally {
      watcher.dispose();
    }
  });

  testWidgets('a system time change shows within about a second', (
    tester,
  ) async {
    // Starts 50 s before its OWN minute boundary (12:01:00), so if the
    // post-jump reschedule below were a no-op — the old timer just left
    // running from this start — it would fire near 12:01:00, not near the
    // genuinely-expected 13:21:00.
    startAt(DateTime(2026, 10, 1, 12, 0, 10));
    try {
      // Someone sets the clock forward by a non-round amount, so the old
      // and new minute boundaries clearly disagree: the jump lands on
      // 13:20:25, whose own next boundary (13:21:00) is 35 s away — not
      // the 50 s the pre-jump schedule would have used.
      wall = wall.add(const Duration(hours: 1, minutes: 20, seconds: 15));
      await tester.pump(WallClockWatcher.checkEvery);
      expect(changes, 1, reason: 'the jump itself is detected');
      await elapse(tester, const Duration(seconds: 34));
      expect(changes, 1, reason: 'not yet — rescheduled from the NEW time');
      await elapse(tester, const Duration(seconds: 1));
      expect(changes, 2, reason: '13:21:00, on the rescheduled timer');
    } finally {
      watcher.dispose();
    }
  });

  testWidgets('coming back to the app refreshes at once', (tester) async {
    startAt(DateTime(2026, 10, 1, 12, 0, 10));
    try {
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      expect(changes, 1);
    } finally {
      watcher.dispose();
    }
  });
}
