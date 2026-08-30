import '../models/tracked_behavior.dart';

/// Persistence interface for [TrackedBehavior], mirroring
/// [TaskRepository]'s shape. UI and state never call Hive directly — see
/// CONSTITUTION.md's access-pattern rule; this is what keeps a future
/// backend swap a new implementation rather than a rewrite.
abstract class TrackedBehaviorRepository {
  List<TrackedBehavior> getBehaviors();
  TrackedBehavior? getBehaviorById(String id);
  Future<void> saveBehavior(TrackedBehavior behavior);
  Future<void> deleteBehavior(String id);
}
