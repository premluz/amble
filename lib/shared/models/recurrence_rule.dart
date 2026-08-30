import 'package:hive_ce/hive_ce.dart';

import 'recurrence_frequency.dart';

part 'recurrence_rule.g.dart';

/// How a recurring series repeats.
///
/// A **value object embedded on the originating [Task]**, not a persisted
/// entity of its own — it has no id and does not extend [HiveObject], per
/// CONSTITUTION.md ("not a persisted entity of its own for MVP"). Only the
/// template (first) instance of a series carries the rule; later instances
/// reference the series via `recurrenceId` alone.
///
/// Deliberately small: no monthly/yearly, no RRULE-style patterns.
@HiveType(typeId: 5)
class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
  }) : assert(interval >= 1, 'interval must be at least 1'),
       assert(
         daysOfWeek == null || daysOfWeek.isNotEmpty,
         'daysOfWeek must be null or non-empty — an empty list would mean '
         '"weekly, on no days", which can never produce an occurrence',
       );

  @HiveField(0)
  final RecurrenceFrequency frequency;

  /// Every N days/weeks. 1 means every day / every week.
  @HiveField(1)
  final int interval;

  /// Which weekdays a [RecurrenceFrequency.weekly] series lands on, using
  /// [DateTime.monday]–[DateTime.sunday] (1–7). Null means "the same
  /// weekday as the template instance". Ignored for daily recurrence.
  @HiveField(2)
  final List<int>? daysOfWeek;

  /// Last date an occurrence may fall on, inclusive. Null means the series
  /// is open-ended — which is exactly why generation uses a rolling window
  /// rather than materializing to the end (see [recurrenceWindowWeeks]).
  @HiveField(3)
  final DateTime? endDate;

  Map<String, dynamic> toJson() => {
    'frequency': frequency.name,
    'interval': interval,
    'daysOfWeek': daysOfWeek,
    'endDate': endDate?.toIso8601String(),
  };

  /// Reconstructs a rule from [toJson]'s output. Throws [FormatException]
  /// for anything malformed, matching `Task.fromJson`'s fail-loud contract.
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final frequencyName = json['frequency'];
    if (frequencyName is! String) {
      throw const FormatException(
        'RecurrenceRule.fromJson: missing or invalid "frequency"',
      );
    }
    RecurrenceFrequency? frequency;
    for (final value in RecurrenceFrequency.values) {
      if (value.name == frequencyName) frequency = value;
    }
    if (frequency == null) {
      throw FormatException(
        'RecurrenceRule.fromJson: unrecognized "frequency" "$frequencyName"',
      );
    }

    final interval = json['interval'];
    if (interval is! int || interval < 1) {
      throw const FormatException(
        'RecurrenceRule.fromJson: missing or invalid "interval"',
      );
    }

    final rawDays = json['daysOfWeek'];
    List<int>? daysOfWeek;
    if (rawDays != null) {
      if (rawDays is! List) {
        throw const FormatException(
          'RecurrenceRule.fromJson: invalid "daysOfWeek"',
        );
      }
      daysOfWeek = rawDays.cast<int>().toList();
    }

    final rawEnd = json['endDate'];
    DateTime? endDate;
    if (rawEnd != null) {
      if (rawEnd is! String) {
        throw const FormatException(
          'RecurrenceRule.fromJson: invalid "endDate"',
        );
      }
      endDate = DateTime.parse(rawEnd);
    }

    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      daysOfWeek: daysOfWeek,
      endDate: endDate,
    );
  }

  /// Field-by-field comparison, used by import's conflict detection. Not an
  /// `==` override, matching `Task.hasSameFieldsAs`'s reasoning.
  bool hasSameFieldsAs(RecurrenceRule other) {
    final days = daysOfWeek;
    final otherDays = other.daysOfWeek;
    final sameDays =
        (days == null && otherDays == null) ||
        (days != null &&
            otherDays != null &&
            days.length == otherDays.length &&
            days.every(otherDays.contains));
    return frequency == other.frequency &&
        interval == other.interval &&
        sameDays &&
        endDate == other.endDate;
  }
}
