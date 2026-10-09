import 'dart:convert';

import '../models/command_log_entry.dart';
import '../models/occurrence_key.dart';
import '../models/occurrence_record.dart';
import '../models/record_aspect.dart';
import '../models/series.dart';
import '../repositories/occurrence_record_repository.dart';
import '../repositories/series_repository.dart';

/// Undo refused because something the command wrote has changed since
/// (docs/RECURRENCE_CONTRACT.md §6). Nothing was modified.
class UndoConflictException implements Exception {
  const UndoConflictException(this.commandId, this.reason);
  final String commandId;
  final String reason;

  @override
  String toString() => 'UndoConflictException($commandId): $reason';
}

/// Writes [values] over [current]; a result with nothing left to say is
/// removed instead of stored, so an undone action leaves no trace (§6).
Future<void> writeOrRemoveRecord(
  OccurrenceRecordRepository records,
  OccurrenceKey key,
  OccurrenceRecord? current,
  Map<RecordAspect, Object?> values, {
  required DateTime now,
}) async {
  final next = writeAspects(key, current, values, now: now);
  if (!next.isEmpty) return records.save(next);
  if (current != null) await records.delete(key);
}

/// Reverts one logged change: only what that command wrote, and only if it
/// still holds the values the command wrote.
class RecurrenceUndo {
  RecurrenceUndo({
    required this._series,
    required this._records,
    required this._now,
  });

  final SeriesRepository _series;
  final OccurrenceRecordRepository _records;
  final DateTime Function() _now;

  Future<void> revert(String commandId, CommandChange change) =>
      switch (change) {
        RecordChange() => _revertRecord(commandId, change),
        SeriesChange() => _revertSeries(commandId, change),
      };

  Future<void> _revertRecord(String commandId, RecordChange change) async {
    final current = _records.get(change.key);
    final present = readAspects(change.key, current, change.after.keys);
    if (_encode(present) != _encode(change.after)) {
      throw UndoConflictException(commandId, 'occurrence changed since');
    }
    await writeOrRemoveRecord(
      _records,
      change.key,
      current,
      change.before,
      now: _now(),
    );
  }

  /// A later series edit blocks undo; so does occurrence data recorded on a
  /// series this command created.
  Future<void> _revertSeries(String commandId, SeriesChange change) async {
    final current = _series.get(change.seriesId);
    if (current == null || current.version != change.afterVersion) {
      throw UndoConflictException(commandId, 'series changed since');
    }
    final before = change.before;
    if (before == null) {
      if (_records.getForSeries(change.seriesId).isNotEmpty) {
        throw UndoConflictException(commandId, 'series has occurrence data');
      }
      return _series.delete(change.seriesId);
    }
    await _series.save(
      Series.fromJson({
        ...before,
        'version': current.version + 1,
        'updatedAt': _now().toIso8601String(),
      }),
    );
  }

  static String _encode(Map<RecordAspect, Object?> aspects) => jsonEncode({
    for (final MapEntry(:key, :value) in aspects.entries) key.name: value,
  });
}
