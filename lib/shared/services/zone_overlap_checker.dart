import '../models/zone.dart';

/// Pure check for whether two zones' time-of-day windows intersect.
///
/// Deliberately separate from `overlapsExistingTask` (`overlap_checker.dart`)
/// rather than a reused/generalized version of it: [Zone] and [Task] don't
/// share a supertype, and `overlapsExistingTask` reasons over a specific
/// `DateTime` + duration on a specific day, while this reasons over
/// minutes-since-midnight with no date at all. Per CONSTITUTION.md — "Zones
/// cannot overlap each other... needs its own check."
///
/// Half-open interval, same semantics as `overlapsExistingTask`: a zone
/// ending exactly when another starts does not count as overlapping.
bool zonesOverlap(Zone a, Zone b) {
  return a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes;
}
