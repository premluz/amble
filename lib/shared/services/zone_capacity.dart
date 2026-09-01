import '../models/task.dart';
import '../models/zone.dart';

/// Pure, read-only capacity calculation for a [Zone] — the sum of
/// [Task.durationMinutes] across every task assigned to it (that also has a
/// [Task.scheduledAt]) versus the zone's own [Zone.durationMinutes].
///
/// Per CONSTITUTION.md: "Capacity is checked, not enforced physically" —
/// what happens when [assignedMinutes] exceeds the zone's duration (hard
/// block, warning, silent overflow) is explicitly undecided and NOT resolved
/// here. This function only computes the numbers; it is deliberately not
/// called from any UI or validation logic yet.
class ZoneCapacity {
  const ZoneCapacity({required this.zone, required this.assignedMinutes});

  final Zone zone;
  final int assignedMinutes;

  int get capacityMinutes => zone.durationMinutes;

  int get remainingMinutes => capacityMinutes - assignedMinutes;

  bool get isOverCapacity => assignedMinutes > capacityMinutes;
}

/// Computes [ZoneCapacity] for [zone] from [tasks] — every task whose
/// `zoneId` matches and that also has a `scheduledAt` (a zone-only task with
/// no `scheduledAt` has nothing to sum, per CONSTITUTION.md).
ZoneCapacity calculateZoneCapacity({
  required Zone zone,
  required List<Task> tasks,
}) {
  final assignedMinutes = tasks
      .where((task) => task.zoneId == zone.id && task.isScheduled)
      .fold<int>(0, (sum, task) => sum + task.durationMinutes!);

  return ZoneCapacity(zone: zone, assignedMinutes: assignedMinutes);
}
