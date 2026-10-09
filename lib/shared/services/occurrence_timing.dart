import 'package:timezone/timezone.dart' as tz;

import '../models/local_date.dart';
import '../models/occurrence_record.dart';
import '../models/resolved_occurrence.dart';
import '../models/zone_history.dart';

/// "Now" plus the time zones needed to place occurrences (contract §7, §11).
///
/// Injected rather than read from the device so DST and travel scenarios
/// are testable. [currentZone] is an IANA name; the `timezone` database must
/// be initialized before use.
class OccurrenceClock {
  OccurrenceClock({
    required this.now,
    required this.currentZone,
    required this.history,
  }) : today = LocalDate.fromDateTime(
         tz.TZDateTime.from(now, tz.getLocation(currentZone)),
       );

  final DateTime now;
  final String currentZone;
  final ZoneHistory history;
  final LocalDate today;

  /// Today and earlier use the zone they began in; later days float (D2).
  tz.Location locationOn(LocalDate date) => tz.getLocation(
    history.zoneNameOn(date, today: today, currentZone: currentZone),
  );

  /// Local wall-clock [minutes] after midnight on [date], in [date]'s zone.
  ///
  /// RFC 5545 rules: a time inside a spring-forward gap (02:30 that never
  /// happens) shifts forward by the gap length (→ 03:30) — the `timezone`
  /// package already does this. A repeated fall-back time resolves to its
  /// FIRST occurrence — the package picks the second, so that is corrected
  /// here.
  tz.TZDateTime wallClock(LocalDate date, int minutes) =>
      _onDay(locationOn(date), date, minutes);

  /// Midnight starting [date] in that date's zone.
  tz.TZDateTime startOfDay(LocalDate date) => wallClock(date, 0);

  /// Midnight ending [date], in the zone [date] itself used — not the next
  /// day's, which may differ after travel.
  tz.TZDateTime endOfDay(LocalDate date) =>
      _onDay(locationOn(date), date.addDays(1), 0);

  static tz.TZDateTime _onDay(tz.Location location, LocalDate date, int min) {
    final resolved = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      min ~/ Duration.minutesPerHour,
      min % Duration.minutesPerHour,
    );
    return _firstOccurrenceOf(location, resolved);
  }

  /// No real zone has two transitions closer together than this.
  static const _transitionProbe = Duration(hours: 3);

  static tz.TZDateTime _firstOccurrenceOf(
    tz.Location location,
    tz.TZDateTime resolved,
  ) {
    final before = tz.TZDateTime.fromMillisecondsSinceEpoch(
      location,
      resolved.millisecondsSinceEpoch - _transitionProbe.inMilliseconds,
    );
    final shift = before.timeZoneOffset - resolved.timeZoneOffset;
    if (shift <= Duration.zero) return resolved;
    final earlier = resolved.subtract(shift);
    final sameWallClock =
        earlier.day == resolved.day &&
        earlier.hour == resolved.hour &&
        earlier.minute == resolved.minute;
    return sameWallClock ? earlier : resolved;
  }
}

/// End is start plus elapsed minutes, so a 60-minute task across a clock
/// change still lasts 60 minutes.
DateTime endAfter(DateTime start, int durationMinutes) =>
    start.add(Duration(minutes: durationMinutes));

/// When an occurrence without an outcome becomes omitted: the later of
/// midnight after its start date and its scheduled end (D9).
DateTime omissionDeadline({
  required OccurrenceClock clock,
  required LocalDate startDate,
  required DateTime end,
}) {
  final midnightAfter = clock.endOfDay(startDate);
  return end.isAfter(midnightAfter) ? end : midnightAfter;
}

OccurrenceStatus statusFor({
  required OccurrenceOutcome outcome,
  required DateTime deadline,
  required DateTime now,
}) => switch (outcome) {
  OccurrenceOutcome.done => OccurrenceStatus.done,
  OccurrenceOutcome.skipped => OccurrenceStatus.skipped,
  OccurrenceOutcome.cancelled => OccurrenceStatus.cancelled,
  OccurrenceOutcome.none =>
    now.isBefore(deadline)
        ? OccurrenceStatus.upcoming
        : OccurrenceStatus.omitted,
};
