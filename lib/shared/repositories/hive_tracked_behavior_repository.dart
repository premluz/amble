import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/tracked_behavior.dart';
import 'tracked_behavior_repository.dart';

class HiveTrackedBehaviorRepository implements TrackedBehaviorRepository {
  HiveTrackedBehaviorRepository(this._box);

  final Box<TrackedBehavior> _box;

  @override
  List<TrackedBehavior> getBehaviors() => _box.values.toList();

  @override
  TrackedBehavior? getBehaviorById(String id) => _box.get(id);

  @override
  Future<void> saveBehavior(TrackedBehavior behavior) =>
      _box.put(behavior.id, behavior);

  @override
  Future<void> deleteBehavior(String id) => _box.delete(id);
}
