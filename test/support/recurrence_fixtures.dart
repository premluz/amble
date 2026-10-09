import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/series.dart';
import 'package:amble/shared/models/series_revision.dart';
import 'package:amble/shared/models/zone_history.dart';
import 'package:amble/shared/services/occurrence_timing.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const london = 'Europe/London';
const newYork = 'America/New_York';
const seriesId = 'run';
const sevenAm = 7 * 60;
const eightAm = 8 * 60;

/// Monday of the reference week used across recurrence tests.
const monday = LocalDate(2026, 10, 5);

final _fixedInstant = DateTime.utc(2026, 1, 1);

void initTimeZones() => tz_data.initializeTimeZones();

RecurrenceRule daily({int interval = 1}) =>
    RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: interval);

RecurrenceRule weekly(List<int> days, {int interval = 1}) => RecurrenceRule(
  frequency: RecurrenceFrequency.weekly,
  interval: interval,
  daysOfWeek: days,
);

SeriesRevision revision({
  LocalDate from = monday,
  RecurrenceRule? rule,
  int start = sevenAm,
  int duration = 45,
  String title = 'Run',
  String? description,
  String? behaviorId,
}) => SeriesRevision(
  effectiveFrom: from,
  rule: rule ?? daily(),
  startMinutes: start,
  durationMinutes: duration,
  defaults: SeriesDefaults(
    title: title,
    description: description,
    behaviorId: behaviorId,
  ),
);

Series series(List<SeriesRevision> revisions) => Series(
  id: seriesId,
  anchor: revisions.first.effectiveFrom,
  revisions: revisions,
  createdAt: _fixedInstant,
  updatedAt: _fixedInstant,
);

ZoneHistoryEntry zoneEntry(LocalDate from, String zone) =>
    ZoneHistoryEntry(effectiveFrom: from, zoneName: zone);

/// A clock at local wall time in [zone], with [history] of past zones.
OccurrenceClock clockAt(
  LocalDate date,
  int minutes, {
  String zone = london,
  List<ZoneHistoryEntry> history = const [],
}) => OccurrenceClock(
  now: tz.TZDateTime(
    tz.getLocation(zone),
    date.year,
    date.month,
    date.day,
    minutes ~/ 60,
    minutes % 60,
  ),
  currentZone: zone,
  history: ZoneHistory(history),
);

DateTime londonTime(LocalDate date, int hour, [int minute = 0]) =>
    tz.TZDateTime(
      tz.getLocation(london),
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
