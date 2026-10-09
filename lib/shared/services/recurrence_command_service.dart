import '../models/command_log_entry.dart';
import '../models/local_date.dart';

import '../models/occurrence_record.dart';
import '../models/recurrence_command.dart';
import '../models/record_aspect.dart';
import '../models/series.dart';
import '../repositories/command_log_repository.dart';
import '../repositories/occurrence_record_repository.dart';
import '../repositories/series_repository.dart';
import '../repositories/stale_write_exception.dart';
import 'recurrence_undo.dart';

/// How long applied commands are remembered for retry detection and undo.
/// Short on purpose: entries hold before/after values, including note text.
const commandLogRetention = Duration(days: 7);

class CommandResult {
  const CommandResult({required this.entry, required this.alreadyApplied});
  final CommandLogEntry entry;

  /// True when this command id had already been applied — a retry, so
  /// nothing was written this time.
  final bool alreadyApplied;
}

/// Applies [RecurrenceCommand]s and undoes them. The only writer of series
/// and occurrence records.
///
/// Retry safety: a command id is applied at most once. A created series uses
/// the command id as its own id, so even a crash between saving the series
/// and logging the command cannot create a duplicate; an occurrence command
/// replayed after such a crash fails its version check instead of applying
/// twice.
class RecurrenceCommandService {
  RecurrenceCommandService({
    required SeriesRepository series,
    required OccurrenceRecordRepository records,
    required this._log,
    required DateTime Function() now,
    required this._today,
  }) : _series = series,
       _records = records,
       _now = now,
       _undo = RecurrenceUndo(series: series, records: records, now: now);

  final SeriesRepository _series;
  final OccurrenceRecordRepository _records;
  final CommandLogRepository _log;
  final DateTime Function() _now;
  final LocalDate Function() _today;
  final RecurrenceUndo _undo;

  Future<CommandResult> execute(RecurrenceCommand command) async {
    final existing = _log.get(command.commandId);
    if (existing != null) {
      return CommandResult(entry: existing, alreadyApplied: true);
    }
    final change = switch (command) {
      CreateSeries() => await _create(command),
      ReviseSeries() => await _revise(command),
      EndSeries() => await _end(command),
      OccurrenceCommand() => await _applyToOccurrence(command),
    };
    final entry = CommandLogEntry(
      commandId: command.commandId,
      appliedAt: _now(),
      change: change,
    );
    await _log.save(entry);
    return CommandResult(entry: entry, alreadyApplied: false);
  }

  /// Reverts exactly what [commandId] changed, or throws
  /// [UndoConflictException] if any of it has changed since. Undoing an
  /// already-undone command does nothing.
  Future<void> undo(String commandId) async {
    final entry = _log.get(commandId);
    if (entry == null) throw StateError('No applied command $commandId');
    if (entry.undone) return;
    await _undo.revert(commandId, entry.change);
    await _log.save(entry.markUndone());
  }

  Future<void> pruneLog() =>
      _log.pruneAppliedBefore(_now().subtract(commandLogRetention));

  Future<SeriesChange> _create(CreateSeries command) async {
    final revision = command.firstRevision;
    final created = Series(
      id: command.commandId,
      anchor: revision.effectiveFrom,
      revisions: [revision],
      createdAt: _now(),
      updatedAt: _now(),
    );
    if (_series.get(created.id) == null) await _series.save(created);
    return SeriesChange(
      seriesId: created.id,
      before: null,
      afterVersion: created.version,
    );
  }

  Future<SeriesChange> _revise(ReviseSeries command) async {
    final current = _requireSeries(command.seriesId, command.expectedVersion);
    final from = Series.effectiveDateFor(command.fromDate, _today());
    final next = current.withRevision(command.draft.from(from), now: _now());
    return _saveSeries(current, next);
  }

  Future<SeriesChange> _end(EndSeries command) async {
    final current = _requireSeries(command.seriesId, command.expectedVersion);
    final next = current.endedAfter(_today().addDays(-1), now: _now());
    return _saveSeries(current, next);
  }

  Future<SeriesChange> _saveSeries(Series current, Series next) async {
    await _series.save(next);
    return SeriesChange(
      seriesId: next.id,
      before: current.toJson(),
      afterVersion: next.version,
    );
  }

  Series _requireSeries(String id, int expectedVersion) {
    final current = _series.get(id);
    if (current == null) throw StateError('No series $id');
    if (current.version != expectedVersion) {
      throw StaleWriteException(
        entity: 'Series',
        id: id,
        storedVersion: current.version,
        attemptedVersion: expectedVersion + 1,
      );
    }
    return current;
  }

  Future<RecordChange> _applyToOccurrence(OccurrenceCommand command) async {
    final key = command.key;
    final current = _records.get(key);
    if (current?.version != command.expectedVersion) {
      throw StaleWriteException(
        entity: 'OccurrenceRecord',
        id: key.storageKey,
        storedVersion: current?.version,
        attemptedVersion: (command.expectedVersion ?? 0) + 1,
      );
    }
    final (aspects, modified) = _target(command, current);
    final after = readAspects(key, modified, aspects);
    await writeOrRemoveRecord(_records, key, current, after, now: _now());
    return RecordChange(
      key: key,
      before: readAspects(key, current, aspects),
      after: after,
    );
  }

  (Set<RecordAspect>, OccurrenceRecord) _target(
    OccurrenceCommand command,
    OccurrenceRecord? current,
  ) {
    final now = _now();
    final base = current ?? OccurrenceRecord(key: command.key, updatedAt: now);
    return switch (command) {
      SetOutcome(:final outcome, :final completionDate) => (
        {RecordAspect.outcome},
        base.withOutcome(outcome, now: now, completionDate: completionDate),
      ),
      SetNote(:final note) => (
        {RecordAspect.note},
        base.withNote(note, now: now),
      ),
      SetMeasuredValue(:final value) => (
        {RecordAspect.measuredValue},
        base.withMeasuredValue(value, now: now),
      ),
      OverridePlan(:final plan, :final fields) => (
        fields,
        base.withPlan(plan, now: now),
      ),
    };
  }
}
