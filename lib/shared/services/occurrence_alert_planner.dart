import '../models/occurrence_alert.dart';
import '../models/resolved_occurrence.dart';
import 'notification_service.dart' show notificationHorizonDays;

/// Most occurrence alerts held at once. iOS keeps only the 64 soonest
/// pending local notifications per app; this leaves room for one-off task
/// and zone alerts within that, and keeps Android far below its
/// 500-alarm cap (docs/ERROR_LOG.md). A time window alone is not a count
/// limit — many daily series can still fill it.
const maxOccurrenceAlerts = 48;

/// The alerts that should exist right now: upcoming, enabled, still part of
/// the plan, starting within the horizon — soonest first, capped at
/// [budget].
List<OccurrenceAlert> planOccurrenceAlerts(
  Iterable<ResolvedOccurrence> occurrences, {
  required DateTime now,
  int budget = maxOccurrenceAlerts,
}) {
  final horizonEnd = now.add(const Duration(days: notificationHorizonDays));
  final due =
      occurrences
          .where(
            (o) =>
                o.status == OccurrenceStatus.upcoming &&
                o.notificationsEnabled &&
                !o.outsideCurrentPlan &&
                o.start.isAfter(now) &&
                o.start.isBefore(horizonEnd),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final o in due.take(budget))
      OccurrenceAlert(key: o.key, title: o.title, at: o.start),
  ];
}
