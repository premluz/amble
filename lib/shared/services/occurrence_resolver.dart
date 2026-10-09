import '../models/field_override.dart';
import '../models/local_date.dart';
import '../models/occurrence_key.dart';
import '../models/occurrence_plan_overrides.dart';
import '../models/occurrence_record.dart';
import '../models/resolved_occurrence.dart';
import '../models/series.dart';
import 'occurrence_timing.dart';
import 'series_expansion.dart';

/// Every occurrence overlapping [from]..[to] (inclusive local dates), with
/// each series revision and per-occurrence record merged — the single query
/// all surfaces read (contract §10). One-off tasks are not included; callers
/// combine them via [ScheduledBlock].
///
/// [records] may contain records outside the range; moved-in ones are found
/// by their current interval. Each key appears at most once in the result.
List<ResolvedOccurrence> resolveOccurrences({
  required Iterable<Series> series,
  required Iterable<OccurrenceRecord> records,
  required LocalDate from,
  required LocalDate to,
  required OccurrenceClock clock,
  bool includeCancelled = false,
}) {
  final seriesById = {for (final s in series) s.id: s};
  final pending = _indexByKey(records);
  final candidates = <ResolvedOccurrence>[];

  // Widened by a day each side so items crossing midnight are found.
  final scanFrom = from.addDays(-1);
  final scanTo = to.addDays(1);
  for (final s in seriesById.values) {
    for (final date in expectedDates(s, scanFrom, scanTo)) {
      final key = OccurrenceKey(seriesId: s.id, date: date);
      candidates.add(
        _resolve(s, key, pending.remove(key), clock, outsidePlan: false),
      );
    }
  }
  for (final record in pending.values) {
    final resolved = _resolveUnscanned(record, seriesById, clock);
    if (resolved != null) candidates.add(resolved);
  }

  final rangeStart = clock.startOfDay(from);
  final rangeEnd = clock.endOfDay(to);
  return candidates
      .where((o) => o.start.isBefore(rangeEnd) && o.end.isAfter(rangeStart))
      .where((o) => includeCancelled || o.status != OccurrenceStatus.cancelled)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// One occurrence by key — the one a user is acting on right now.
ResolvedOccurrence resolveOccurrence({
  required Series series,
  required OccurrenceKey key,
  required OccurrenceRecord? record,
  required OccurrenceClock clock,
}) => _resolve(
  series,
  key,
  record,
  clock,
  outsidePlan:
      key.ordinal != OccurrenceKey.firstOrdinal ||
      !isExpectedOn(series, key.date),
);

/// A record whose key date was not scanned: either moved in from outside
/// the range, or on a date its series no longer expects (§9).
ResolvedOccurrence? _resolveUnscanned(
  OccurrenceRecord record,
  Map<String, Series> seriesById,
  OccurrenceClock clock,
) {
  final s = seriesById[record.key.seriesId];
  if (s == null) {
    throw StateError('Occurrence record ${record.key} has no series');
  }
  if (record.key.ordinal == OccurrenceKey.firstOrdinal &&
      isExpectedOn(s, record.key.date)) {
    return _resolve(s, record.key, record, clock, outsidePlan: false);
  }
  // No longer expected: only user-entered facts keep it visible.
  if (!record.hasContent) return null;
  return _resolve(s, record.key, record, clock, outsidePlan: true);
}

ResolvedOccurrence _resolve(
  Series s,
  OccurrenceKey key,
  OccurrenceRecord? record,
  OccurrenceClock clock, {
  required bool outsidePlan,
}) {
  final revision = s.revisionOn(key.date);
  if (revision == null) {
    throw StateError('Occurrence $key is before its series started');
  }
  final plan = record?.plan ?? const OccurrencePlanOverrides();
  final defaults = revision.defaults;
  final startAt = resolveField(
    plan.start,
    OccurrenceStart(date: key.date, minutes: revision.startMinutes),
  );
  final start = clock.wallClock(startAt.date, startAt.minutes);
  final end = endAfter(
    start,
    resolveField(plan.durationMinutes, revision.durationMinutes),
  );
  return ResolvedOccurrence(
    key: key,
    status: statusFor(
      outcome: record?.outcome ?? OccurrenceOutcome.none,
      deadline: omissionDeadline(
        clock: clock,
        startDate: startAt.date,
        end: end,
      ),
      now: clock.now,
    ),
    start: start,
    end: end,
    title: resolveField(plan.title, defaults.title),
    description: resolveClearable(plan.description, defaults.description),
    categoryId: resolveClearable(plan.categoryId, defaults.categoryId),
    zoneId: resolveClearable(plan.zoneId, defaults.zoneId),
    behaviorId: defaults.behaviorId,
    notificationsEnabled: resolveField(
      plan.notificationsEnabled,
      defaults.notificationsEnabled,
    ),
    isImportant: resolveField(plan.isImportant, defaults.isImportant),
    outsideCurrentPlan: outsidePlan,
    measuredValue: record?.measuredValue,
    note: record?.note,
    completionDate: record?.completionDate,
    outcomeRecordedAt: record?.outcomeRecordedAt,
  );
}

/// At most one record per key (§3) — a duplicate is corrupt data, so fail
/// loudly rather than pick one.
Map<OccurrenceKey, OccurrenceRecord> _indexByKey(
  Iterable<OccurrenceRecord> records,
) {
  final index = <OccurrenceKey, OccurrenceRecord>{};
  for (final record in records) {
    if (index.containsKey(record.key)) {
      throw StateError('Duplicate occurrence record for ${record.key}');
    }
    index[record.key] = record;
  }
  return index;
}
