import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import 'behavior_target_type.dart';

part 'tracked_behavior.g.dart';

const _uuid = Uuid();

/// A persistent intention that accumulates evidence across many scheduled
/// [Task] instances over time — e.g. "Exercise, 60 minutes, 3x/week".
///
/// Distinct from a *recurring* task, which is only a scheduling property of
/// an ordinary [Task] and implies no tracking, history, or target. See
/// CONSTITUTION.md ("Recurring vs. tracked behavior") — conflating the two
/// is the specific mistake this separation exists to prevent.
///
/// Deliberately minimal for MVP: no cue/context fields, no reflection
/// scale, no learning or suggestion engine. A [Task] links back here via
/// its nullable `behaviorId`, and records its outcome in `actualAmount`.
///
/// This model is inert until the TrackedBehavior UI is built — see
/// `core/feature_flags.dart`. The data layer is never "turned off," only
/// left dormant.
@HiveType(typeId: 3)
class TrackedBehavior extends HiveObject {
  TrackedBehavior({
    required this.id,
    required this.title,
    required this.targetType,
    this.targetAmount,
    this.minimumAmount,
    required this.timesPerWeek,
    this.schemaVersion = 1,
  }) : assert(
         targetType == BehaviorTargetType.binary || targetAmount != null,
         'targetAmount is required unless targetType is binary',
       );

  /// Creates a new tracked behavior with a client-generated UUID — same
  /// `uuid` call [Task.create] uses, per the Constitution's "IDs are
  /// client-generated UUIDs from day one" rule.
  TrackedBehavior.create({
    required String title,
    required BehaviorTargetType targetType,
    num? targetAmount,
    num? minimumAmount,
    required int timesPerWeek,
  }) : this(
         id: _uuid.v4(),
         title: title,
         targetType: targetType,
         targetAmount: targetAmount,
         minimumAmount: minimumAmount,
         timesPerWeek: timesPerWeek,
       );

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  BehaviorTargetType targetType;

  /// The full intended amount, in [targetType]'s unit. Null only when
  /// [targetType] is [BehaviorTargetType.binary], which has no amount to
  /// hit — enforced by the constructor's assert.
  @HiveField(3)
  num? targetAmount;

  /// An optional smaller "still counts" amount — the fallback version of
  /// the behavior for a bad day, per CONSTITUTION.md. Always optional,
  /// including for non-binary targets.
  @HiveField(4)
  num? minimumAmount;

  /// How many times per week this is intended. A plain int for MVP, not a
  /// general recurrence rule — that's explicitly out of scope (SCOPE.md).
  @HiveField(5)
  int timesPerWeek;

  @HiveField(6)
  int schemaVersion;

  /// True when this behavior is simply "did it happen," with no amount.
  bool get isBinary => targetType == BehaviorTargetType.binary;
}
