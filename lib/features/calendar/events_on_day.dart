import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/external_calendar_event.dart';
import '../../shared/providers/calendar_providers.dart';

/// The events that overlap [day], by start. A multi-day event appears on
/// every day it covers; the grid clips it to that day (see [minutesOnDay]).
List<ExternalCalendarEvent> eventsOnDay(
  Iterable<ExternalCalendarEvent> events,
  DateTime day,
) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  return events
      .where(
        (e) =>
            e.start.isBefore(end) && (e.end.isAfter(start) || e.start == start),
      )
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// [moment] as minutes since midnight on [day], clamped to that day.
int minutesOnDay(DateTime moment, DateTime day) {
  final midnight = DateTime(day.year, day.month, day.day);
  return moment.difference(midnight).inMinutes.clamp(0, Duration.minutesPerDay);
}

/// Whether [event] covers whole days (a day or longer), so has no place on
/// an hour grid.
bool isAllDay(ExternalCalendarEvent event) =>
    event.end.difference(event.start) >= const Duration(days: 1);

/// The device-calendar events from the start of [first] to the end of
/// [last], empty while loading or when unavailable (no permission, no
/// calendars selected): events never block the tasks around them. Re-reads
/// on a calendar refresh.
List<ExternalCalendarEvent> watchEventsBetween(
  WidgetRef ref,
  DateTime first,
  DateTime last,
) =>
    ref
        .watch(
          externalCalendarEventsForRangeProvider(
            DateTime(first.year, first.month, first.day),
            DateTime(last.year, last.month, last.day + 1),
          ),
        )
        .value ??
    const [];
