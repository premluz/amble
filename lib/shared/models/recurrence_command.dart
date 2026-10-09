import 'local_date.dart';
import 'occurrence_key.dart';
import 'occurrence_plan_overrides.dart';
import 'occurrence_record.dart';
import 'recurrence_rule.dart';
import 'record_aspect.dart';
import 'series_revision.dart';

/// One user action on repeating tasks — the single write boundary shared by
/// UI, Siri and any future tool (docs/RECURRENCE_CONTRACT.md §12).
///
/// [commandId] is generated once by the caller and reused on retry, so a
/// retried command is never applied twice.
sealed class RecurrenceCommand {
  const RecurrenceCommand(this.commandId);
  final String commandId;
}

/// A new series starting on [firstRevision]'s effective date.
final class CreateSeries extends RecurrenceCommand {
  const CreateSeries(super.commandId, {required this.firstRevision});
  final SeriesRevision firstRevision;
}

/// The fields of a revision, before its effective date is decided.
class SeriesRevisionDraft {
  const SeriesRevisionDraft({
    required this.rule,
    required this.startMinutes,
    required this.durationMinutes,
    required this.defaults,
  });

  final RecurrenceRule rule;
  final int startMinutes;
  final int durationMinutes;
  final SeriesDefaults defaults;

  SeriesRevision from(LocalDate effectiveFrom) => SeriesRevision(
    effectiveFrom: effectiveFrom,
    rule: rule,
    startMinutes: startMinutes,
    durationMinutes: durationMinutes,
    defaults: defaults,
  );
}

/// "This and following" from [fromDate], or "all" with [fromDate] = today.
/// Never reaches the past: a past [fromDate] takes effect today (D4a, D10).
final class ReviseSeries extends RecurrenceCommand {
  const ReviseSeries(
    super.commandId, {
    required this.seriesId,
    required this.expectedVersion,
    required this.fromDate,
    required this.draft,
  });

  final String seriesId;
  final int expectedVersion;
  final LocalDate fromDate;
  final SeriesRevisionDraft draft;
}

/// "Delete series": no occurrences from today on; history is kept.
final class EndSeries extends RecurrenceCommand {
  const EndSeries(
    super.commandId, {
    required this.seriesId,
    required this.expectedVersion,
  });

  final String seriesId;
  final int expectedVersion;
}

/// A change to one occurrence. [expectedVersion] is the record version the
/// caller saw — null when it saw no record (an untouched occurrence).
sealed class OccurrenceCommand extends RecurrenceCommand {
  const OccurrenceCommand(
    super.commandId, {
    required this.key,
    required this.expectedVersion,
  });

  final OccurrenceKey key;
  final int? expectedVersion;
}

/// Done, skipped, cancelled ("delete this occurrence"), or back to none.
final class SetOutcome extends OccurrenceCommand {
  const SetOutcome(
    super.commandId, {
    required super.key,
    required super.expectedVersion,
    required this.outcome,
    this.completionDate,
  });

  final OccurrenceOutcome outcome;

  /// Required for [OccurrenceOutcome.done] — the local date it was done (D8).
  final LocalDate? completionDate;
}

final class SetNote extends OccurrenceCommand {
  const SetNote(
    super.commandId, {
    required super.key,
    required super.expectedVersion,
    required this.note,
  });

  final String? note;
}

final class SetMeasuredValue extends OccurrenceCommand {
  const SetMeasuredValue(
    super.commandId, {
    required super.key,
    required super.expectedVersion,
    required this.value,
  });

  final num? value;
}

/// "This occurrence" edit: writes [fields] from [plan], leaving every other
/// plan field as it is. Fields set to `Inherit` reset to the series.
final class OverridePlan extends OccurrenceCommand {
  OverridePlan(
    super.commandId, {
    required super.key,
    required super.expectedVersion,
    required this.plan,
    required this.fields,
  }) {
    if (fields.isEmpty || !fields.every((f) => f.isPlanField)) {
      throw ArgumentError.value(fields, 'fields', 'must be plan fields');
    }
  }

  final OccurrencePlanOverrides plan;
  final Set<RecordAspect> fields;
}
