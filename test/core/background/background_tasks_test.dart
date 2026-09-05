import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/background/background_tasks.dart';

void main() {
  group('durationUntilNextTargetHourForTest', () {
    test('before the target hour today: waits until today\'s occurrence', () {
      final now = DateTime(2026, 9, 2, 5, 30); // 05:30
      final duration = durationUntilNextTargetHourForTest(now);

      expect(now.add(duration), DateTime(2026, 9, 2, morningSummaryTargetHour));
    });

    test('after the target hour today: waits until tomorrow\'s occurrence', () {
      final now = DateTime(2026, 9, 2, 14, 0); // 14:00, well past 7am
      final duration = durationUntilNextTargetHourForTest(now);

      expect(now.add(duration), DateTime(2026, 9, 3, morningSummaryTargetHour));
    });

    test('exactly at the target hour: treated as already passed, rolls to '
        'tomorrow (not a zero-duration/immediate re-fire)', () {
      final now = DateTime(2026, 9, 2, morningSummaryTargetHour, 0);
      final duration = durationUntilNextTargetHourForTest(now);

      expect(now.add(duration), DateTime(2026, 9, 3, morningSummaryTargetHour));
    });

    test('a minute before the target hour: waits just one minute', () {
      final now = DateTime(2026, 9, 2, morningSummaryTargetHour - 1, 59);
      final duration = durationUntilNextTargetHourForTest(now);

      expect(duration, const Duration(minutes: 1));
    });
  });
}
