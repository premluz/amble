import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_boundary_markers.dart';

void main() {
  test('starts at the next whole hour at or after rangeStart', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 6, 47),
      DateTime(2026, 8, 21, 9, 0),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [
      DateTime(2026, 8, 21, 7, 0),
      DateTime(2026, 8, 21, 8, 0),
      DateTime(2026, 8, 21, 9, 0),
    ]);
  });

  test(
    'a rangeStart already on a whole hour is included as the first tick',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 11, 0),
        DateTime(2026, 8, 21, 13, 0),
      );

      final times = ticks.map((t) => t.time).toList();
      expect(times, [
        DateTime(2026, 8, 21, 11, 0),
        DateTime(2026, 8, 21, 12, 0),
        DateTime(2026, 8, 21, 13, 0),
      ]);
    },
  );

  test('the last tick is at or before rangeEnd, never after', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 6, 0),
      DateTime(2026, 8, 21, 8, 59),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [
      DateTime(2026, 8, 21, 6, 0),
      DateTime(2026, 8, 21, 7, 0),
      DateTime(2026, 8, 21, 8, 0),
    ]);
  });

  test(
    'a range shorter than one hour with no whole hour inside produces no ticks',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 6, 10),
        DateTime(2026, 8, 21, 6, 40),
      );

      expect(ticks, isEmpty);
    },
  );

  test(
    'intervalHours spaces ticks further apart, still anchored to whole hours',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 6, 0),
        DateTime(2026, 8, 21, 12, 0),
        intervalHours: 2,
      );

      final times = ticks.map((t) => t.time).toList();
      expect(times, [
        DateTime(2026, 8, 21, 6, 0),
        DateTime(2026, 8, 21, 8, 0),
        DateTime(2026, 8, 21, 10, 0),
        DateTime(2026, 8, 21, 12, 0),
      ]);
    },
  );

  test('a range crossing midnight into the next day still ticks correctly', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 23, 30),
      DateTime(2026, 8, 22, 1, 30),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [DateTime(2026, 8, 22, 0, 0), DateTime(2026, 8, 22, 1, 0)]);
  });
}
