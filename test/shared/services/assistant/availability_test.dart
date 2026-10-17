import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/scheduled_block.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/availability.dart';
import 'package:flutter_test/flutter_test.dart';

// Monday 12 Oct 2026.
final _monday = DateTime(2026, 10, 12);

DateTime _t(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

Task _task(int day, int hour, int minutes, [int minute = 0]) => Task.create(
  title: 'task',
  scheduledAt: _t(day, hour, minute),
  durationMinutes: minutes,
  categoryId: BuiltInCategoryIds.general,
);

ExternalCalendarEvent _event(int day, int hour, int minutes) =>
    ExternalCalendarEvent(
      id: 'e$day$hour',
      title: 'Meeting',
      start: _t(day, hour),
      end: _t(day, hour).add(Duration(minutes: minutes)),
      sourceCalendarId: 'cal',
    );

List<FreeWindow> _free(
  List<ScheduledBlock> busy, {
  int days = 1,
  int minMinutes = 30,
  List<Zone> zones = const [],
  String? zoneName,
  DateTime? from,
}) => computeFreeWindows(
  busy: busy,
  zonesOn: (_) => zones,
  from: from ?? _monday,
  to: _monday.add(Duration(days: days)),
  dayStartMinutes: 9 * 60,
  dayEndMinutes: 17 * 60,
  minMinutes: minMinutes,
  zoneName: zoneName,
);

void main() {
  test('an empty day is one window across the planning hours', () {
    final free = _free(const []);
    expect(free, hasLength(1));
    expect(free.single.start, _t(12, 9));
    expect(free.single.end, _t(12, 17));
  });

  test(
    'tasks and imported events are both busy; back-to-back leaves no gap',
    () {
      final free = _free([
        _task(12, 9, 60),
        _task(12, 10, 60),
        _event(12, 13, 90),
      ]);
      expect(
        [for (final w in free) (w.start, w.end)],
        [(_t(12, 11), _t(12, 13)), (_t(12, 14, 30), _t(12, 17))],
      );
    },
  );

  test('overlapping blocks are merged, not double-counted', () {
    final free = _free([_task(12, 9, 120), _event(12, 10, 30)]);
    expect(free.first.start, _t(12, 11));
  });

  test('windows shorter than min_minutes are dropped', () {
    final free = _free([
      _task(12, 9, 60),
      _task(12, 10, 20, 20),
    ], minMinutes: 30);
    // 10:00-10:20 is only 20 minutes.
    expect(free.every((w) => w.minutes >= 30), isTrue);
    expect(free.any((w) => w.start == _t(12, 10)), isFalse);
  });

  test('a start time mid-day hides the morning', () {
    final free = _free(const [], from: _t(12, 15));
    expect(free.single.start, _t(12, 15));
  });

  test('windows report the zones they overlap', () {
    final focus = Zone(
      id: 'z',
      title: 'Focus',
      startMinutes: 9 * 60,
      endMinutes: 12 * 60,
    );
    final free = _free(const [], zones: [focus]);
    expect(free.single.zoneNames, ['Focus']);
  });

  test('zone_name keeps only time inside that zone', () {
    final focus = Zone(
      id: 'z',
      title: 'Focus',
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    );
    final free = _free([_task(12, 10, 30)], zones: [focus], zoneName: 'focus');
    expect(
      [for (final w in free) (w.start, w.end)],
      [(_t(12, 10, 30), _t(12, 12))],
    );
  });

  test('"four one-hour slots this week" has enough to choose from', () {
    final busy = <ScheduledBlock>[
      for (var day = 12; day <= 16; day++) ...[
        _task(day, 9, 180),
        _event(day, 13, 240),
      ],
    ];
    final free = _free(busy, days: 7, minMinutes: 60);
    // Mon-Fri: 12:00-13:00 is free each day; the weekend is wide open.
    expect(free.where((w) => w.minutes >= 60).length, greaterThanOrEqualTo(4));
    expect(free.first.start, _t(12, 12));
    expect(free.first.end, _t(12, 13));
  });
}
