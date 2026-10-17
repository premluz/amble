import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/calendar/calendar_span.dart';
import 'package:amble/features/calendar/week_zone_bands.dart';
import 'package:amble/shared/models/zone.dart';

/// "1 zone across the whole week, not individual zones per day": the same
/// zone (name and hours) on consecutive days is one run.
Zone _placement(
  String title,
  int weekday,
  int start,
  int end, {
  String? facet,
}) => Zone(
  id: '$title-$weekday',
  title: title,
  startMinutes: start,
  endMinutes: end,
  weekday: weekday,
  facetId: facet,
);

void main() {
  final days = weekDaysOf(DateTime(2026, 10, 14)); // Mon 12 – Sun 18

  test('the same zone Monday to Friday is one run across five days', () {
    final zones = [
      for (var d = 1; d <= 5; d++) _placement('Work', d, 9 * 60, 17 * 60),
    ];
    final runs = weekZoneRuns(zones, days);
    expect(runs, hasLength(1));
    expect(runs.single.first, 0);
    expect(runs.single.last, 4);
  });

  test('a zone on every day is one run across the whole week', () {
    final zones = [
      for (var d = 1; d <= 7; d++) _placement('Sleep', d, 0, 7 * 60),
    ];
    final run = weekZoneRuns(zones, days).single;
    expect((run.first, run.last), (0, 6));
  });

  test('different hours on a day, or a gap day, start another run', () {
    final zones = [
      _placement('Work', 1, 9 * 60, 17 * 60),
      _placement('Work', 2, 9 * 60, 17 * 60),
      _placement('Work', 3, 10 * 60, 12 * 60), // different hours
      _placement('Work', 5, 9 * 60, 17 * 60), // Thursday has none: a gap
      _placement('Work', 6, 9 * 60, 17 * 60),
    ];
    final runs = weekZoneRuns(zones, days)
      ..sort((a, b) => a.first.compareTo(b.first));
    expect([for (final r in runs) (r.first, r.last)], [(0, 1), (2, 2), (4, 5)]);
  });

  test('zones with the same facet but different titles are still one run', () {
    final zones = [
      _placement('Work', 1, 9 * 60, 17 * 60, facet: 'f'),
      _placement('Office', 2, 9 * 60, 17 * 60, facet: 'f'),
    ];
    expect(weekZoneRuns(zones, days), hasLength(1));
  });

  test('different zones at the same hours stay separate', () {
    final zones = [
      _placement('Work', 1, 9 * 60, 17 * 60),
      _placement('Gym', 1, 9 * 60, 17 * 60),
    ];
    expect(weekZoneRuns(zones, days), hasLength(2));
  });
}
