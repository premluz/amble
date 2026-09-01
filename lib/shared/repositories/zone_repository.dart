import '../models/zone.dart';

/// Persistence interface for [Zone], mirroring [TrackedBehaviorRepository]'s
/// shape. UI and state never call Hive directly — see CONSTITUTION.md's
/// access-pattern rule; this is what keeps a future backend swap a new
/// implementation rather than a rewrite.
abstract class ZoneRepository {
  List<Zone> getAll();
  Zone? getById(String id);
  Future<void> save(Zone zone);
  Future<void> delete(String id);
}
