import 'occurrence_key.dart';
import 'occurrence_record.dart';

/// The independently-changeable parts of an [OccurrenceRecord]. A command
/// writes a set of aspects; undo reverts exactly those aspects and nothing
/// else (docs/RECURRENCE_CONTRACT.md §6) — so undoing "done" leaves a note
/// added afterwards intact.
enum RecordAspect {
  start,
  durationMinutes,
  title,
  description,
  categoryId,
  zoneId,
  notificationsEnabled,
  isImportant,

  /// Outcome, completion date and recorded-at move together — they are
  /// validated as one fact.
  outcome,
  measuredValue,
  note;

  bool get isPlanField => index <= isImportant.index;

  static final planFields = values.where((a) => a.isPlanField).toSet();
}

const _outcomeFields = ['outcome', 'completionDate', 'outcomeRecordedAt'];
final _epoch = DateTime.utc(1970);

/// The stored JSON value of each of [aspects] on [record] (an absent record
/// reads as "nothing differs from the series").
Map<RecordAspect, Object?> readAspects(
  OccurrenceKey key,
  OccurrenceRecord? record,
  Iterable<RecordAspect> aspects,
) {
  final json = (record ?? OccurrenceRecord(key: key, updatedAt: _epoch))
      .toJson();
  final plan = _planOf(json);
  return {
    for (final aspect in aspects)
      aspect: switch (aspect) {
        RecordAspect.outcome => {for (final f in _outcomeFields) f: json[f]},
        RecordAspect.measuredValue => json['measuredValue'],
        RecordAspect.note => json['note'],
        _ => plan[aspect.name],
      },
  };
}

/// [current] with [values] written over the matching aspects, one version
/// later (or the initial version for a new record).
OccurrenceRecord writeAspects(
  OccurrenceKey key,
  OccurrenceRecord? current,
  Map<RecordAspect, Object?> values, {
  required DateTime now,
}) {
  final json = (current ?? OccurrenceRecord(key: key, updatedAt: now)).toJson();
  final plan = Map<String, dynamic>.from(_planOf(json));
  for (final MapEntry(key: aspect, :value) in values.entries) {
    switch (aspect) {
      case RecordAspect.outcome:
        final fields = value is Map ? value : const <String, Object?>{};
        for (final f in _outcomeFields) {
          json[f] = fields[f];
        }
      case RecordAspect.measuredValue || RecordAspect.note:
        json[aspect.name] = value;
      default:
        plan[aspect.name] = value;
    }
  }
  json['plan'] = plan;
  json['updatedAt'] = now.toIso8601String();
  json['version'] = current == null
      ? OccurrenceRecord.initialVersion
      : current.version + 1;
  return OccurrenceRecord.fromJson(json);
}

Map<String, dynamic> _planOf(Map<String, dynamic> json) {
  final plan = json['plan'];
  if (plan is! Map<String, dynamic>) {
    throw StateError('OccurrenceRecord.toJson produced no plan map');
  }
  return plan;
}
