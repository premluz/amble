import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/behavior_target_type.dart';
import '../models/tracked_behavior.dart';
import '../repositories/hive_tracked_behavior_repository.dart';
import '../repositories/tracked_behavior_repository.dart';

part 'tracked_behavior_providers.g.dart';

const trackedBehaviorBoxName = 'tracked_behaviors';

@Riverpod(keepAlive: true)
TrackedBehaviorRepository trackedBehaviorRepository(Ref ref) {
  final box = Hive.box<TrackedBehavior>(trackedBehaviorBoxName);
  return HiveTrackedBehaviorRepository(box);
}

/// CRUD state over [TrackedBehaviorRepository], mirroring [TaskList].
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — the TrackedBehavior UI doesn't exist
/// and is gated behind [FeatureFlags.trackedBehaviorEnabled]. It's built
/// now so the data layer is complete and testable ahead of that UI.
@Riverpod(keepAlive: true)
class TrackedBehaviorList extends _$TrackedBehaviorList {
  @override
  List<TrackedBehavior> build() {
    return ref.watch(trackedBehaviorRepositoryProvider).getBehaviors();
  }

  Future<void> createBehavior({
    required String title,
    required BehaviorTargetType targetType,
    num? targetAmount,
    num? minimumAmount,
    required int timesPerWeek,
  }) async {
    final behavior = TrackedBehavior.create(
      title: title,
      targetType: targetType,
      targetAmount: targetAmount,
      minimumAmount: minimumAmount,
      timesPerWeek: timesPerWeek,
    );
    await ref.read(trackedBehaviorRepositoryProvider).saveBehavior(behavior);
    _refresh();
  }

  Future<void> updateBehavior(TrackedBehavior behavior) async {
    await ref.read(trackedBehaviorRepositoryProvider).saveBehavior(behavior);
    _refresh();
  }

  Future<void> deleteBehavior(String id) async {
    await ref.read(trackedBehaviorRepositoryProvider).deleteBehavior(id);
    _refresh();
  }

  void _refresh() {
    state = ref.read(trackedBehaviorRepositoryProvider).getBehaviors();
  }
}
