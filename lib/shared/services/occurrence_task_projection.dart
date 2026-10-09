import '../models/local_date.dart';
import '../models/occurrence_record.dart';
import '../models/occurrence_alert.dart';
import '../models/occurrence_key.dart';
import '../models/recurrence_rule.dart';
import '../models/resolved_occurrence.dart';
import '../models/series.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import 'occurrence_resolver.dart';
import 'occurrence_timing.dart';

/// Shows a series occurrence through the existing `Task`-based UI without
/// it ever becoming a stored task.
///
/// The id is the occurrence's notification payload form
/// (`occurrence:<series>|<date>|<ordinal>`), so every `TaskList` mutator can
/// recognise it and route the change to a series command instead, and the
/// task repository refuses to store it.
bool isOccurrenceTaskId(String id) => occurrenceKeyFromPayload(id) != null;

OccurrenceKey occurrenceKeyOfTask(Task task) {
  final key = occurrenceKeyFromPayload(task.id);
  if (key == null) throw StateError('Task ${task.id} is not an occurrence');
  return key;
}

String occurrenceTaskId(OccurrenceKey key) => occurrencePayload(key);

/// [rule] is the revision's rule on the occurrence's date. It is carried on
/// the projection so the edit sheet can show the repeat days without
/// looking for a stored series template row (there is none).
Task occurrenceAsTask(ResolvedOccurrence occurrence, RecurrenceRule rule) {
  // Wall-clock fields in the zone the occurrence's day uses (contract §7),
  // not `.toLocal()`: after travel a past day still shows its own times,
  // and [localSlotOf] reads edits back in the same terms.
  final start = occurrence.start;
  final status = switch (occurrence.status) {
    OccurrenceStatus.done => TaskStatus.completed,
    OccurrenceStatus.skipped => TaskStatus.skipped,
    _ => TaskStatus.pending,
  };
  return Task(
    id: occurrenceTaskId(occurrence.key),
    title: occurrence.title,
    description: occurrence.description,
    notes: occurrence.note,
    scheduledAt: DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    ),
    durationMinutes: occurrence.end.difference(occurrence.start).inMinutes,
    status: status,
    completedAt: status == TaskStatus.completed
        ? occurrence.outcomeRecordedAt
        : null,
    behaviorId: occurrence.behaviorId,
    actualAmount: occurrence.measuredValue,
    recurrenceId: occurrence.key.seriesId,
    recurrenceRule: rule,
    notificationsEnabled: occurrence.notificationsEnabled,
    categoryId: occurrence.categoryId,
    zoneId: occurrence.zoneId,
    isImportant: occurrence.isImportant,
  );
}

/// Local date and minutes after midnight of a device-local [at].
({LocalDate date, int minutes}) localSlotOf(DateTime at) => (
  date: LocalDate.fromDateTime(at),
  minutes: at.hour * Duration.minutesPerHour + at.minute,
);

/// Every series occurrence overlapping [from]..[to] (inclusive), shown as
/// tasks — the one place occurrences become tasks, used by the in-app store
/// and by the background morning summary (no providers there).
List<Task> occurrenceTasksBetween({
  required Iterable<Series> series,
  required Iterable<OccurrenceRecord> records,
  required LocalDate from,
  required LocalDate to,
  required OccurrenceClock clock,
}) {
  final byId = {for (final s in series) s.id: s};
  return [
    for (final occurrence in resolveOccurrences(
      series: byId.values,
      records: records,
      from: from,
      to: to,
      clock: clock,
    ))
      occurrenceAsTask(occurrence, _ruleFor(byId, occurrence.key)),
  ];
}

RecurrenceRule _ruleFor(Map<String, Series> seriesById, OccurrenceKey key) {
  final revision = seriesById[key.seriesId]?.revisionOn(key.date);
  if (revision == null) throw StateError('No revision for $key');
  return revision.rule;
}
