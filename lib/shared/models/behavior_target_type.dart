import 'package:hive_ce/hive_ce.dart';

part 'behavior_target_type.g.dart';

/// What a [TrackedBehavior]'s target is measured in.
///
/// - [duration] — minutes (e.g. "Exercise, 60 min")
/// - [count] — repetitions (e.g. "Read, 20 pages")
/// - [binary] — did it happen at all; carries no target amount
///
/// Kept deliberately small per CONSTITUTION.md — no cue/context or
/// reflection dimensions, which are future territory, not MVP architecture.
@HiveType(typeId: 4)
enum BehaviorTargetType {
  @HiveField(0)
  duration,
  @HiveField(1)
  count,
  @HiveField(2)
  binary,
}
