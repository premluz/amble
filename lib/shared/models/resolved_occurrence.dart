import 'local_date.dart';
import 'occurrence_key.dart';
import 'scheduled_block.dart';

/// An occurrence's state as of "now" (contract §5). [upcoming] and [omitted]
/// are computed from time; the rest come from what the user recorded.
enum OccurrenceStatus { upcoming, omitted, skipped, done, cancelled }

/// One occurrence with its series revision and per-occurrence data merged —
/// what every surface (Timeline, notifications, behavior progress) reads.
/// Implements [ScheduledBlock] so the existing lane layout can position it.
class ResolvedOccurrence implements ScheduledBlock {
  const ResolvedOccurrence({
    required this.key,
    required this.status,
    required this.start,
    required this.end,
    required this.title,
    required this.notificationsEnabled,
    required this.isImportant,
    required this.outsideCurrentPlan,
    this.description,
    this.categoryId,
    this.zoneId,
    this.behaviorId,
    this.measuredValue,
    this.note,
    this.completionDate,
    this.outcomeRecordedAt,
  });

  final OccurrenceKey key;
  final OccurrenceStatus status;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;
  final String? categoryId;
  final String? zoneId;
  final String? behaviorId;
  final bool notificationsEnabled;
  final bool isImportant;

  /// True when the series no longer expects this date but the user recorded
  /// something on it, so it stays visible (contract §9). Not counted as
  /// expected.
  final bool outsideCurrentPlan;

  final num? measuredValue;
  final String? note;
  final LocalDate? completionDate;
  final DateTime? outcomeRecordedAt;

  /// Whether streak metrics count this as an expected occurrence (§5, D3).
  bool get countsAsExpected =>
      !outsideCurrentPlan &&
      status != OccurrenceStatus.upcoming &&
      status != OccurrenceStatus.cancelled;

  @override
  String get id => key.storageKey;

  @override
  DateTime get scheduledStart => start;

  @override
  DateTime get scheduledEnd => end;
}
