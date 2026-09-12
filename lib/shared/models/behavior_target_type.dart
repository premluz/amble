import 'package:hive_ce/hive_ce.dart';

part 'behavior_target_type.g.dart';

/// What a [TrackedBehavior]'s target is measured in.
///
/// - [duration] — minutes (e.g. "Exercise, 60 min")
/// - [count] — a generic tally (e.g. "Cigarettes, 3")
/// - [distance] — kilometers (e.g. "Run, 5 km")
/// - [reps] — repetitions (e.g. "Push-ups, 20 reps") — a distinct concept
///   from [count]: reps are a physical repetition count, count is any
///   other generic tally, confirmed via AskUserQuestion as two separate
///   options rather than one relabeled variant
/// - [custom] — a user-defined unit (e.g. "Water, 8 glasses") — see
///   [TrackedBehavior.customUnitLabel]/[TrackedBehavior.customUnitName]
/// - [binary] — did it happen at all; carries no target amount
///
/// Kept deliberately small per CONSTITUTION.md — no cue/context or
/// reflection dimensions, which are future territory, not MVP architecture.
/// [distance]/[reps]/[custom] added 2026-09-10, requested directly as "Unit
/// of measure: Time, Distance, Reps, Count[, Custom]".
@HiveType(typeId: 4)
enum BehaviorTargetType {
  @HiveField(0)
  duration,
  @HiveField(1)
  count,
  @HiveField(2)
  binary,
  @HiveField(3)
  distance,
  @HiveField(4)
  custom,
  @HiveField(5)
  reps,
}
