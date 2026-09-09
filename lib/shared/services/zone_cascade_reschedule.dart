import '../models/task.dart';
import '../models/zone.dart';

/// One zone's shift as part of a cascade, paired with every task that
/// moves along with it — mirrors [TaskMove]'s own "id, not object" shape
/// (`shared/services/cascade_reschedule.dart`) so the caller resolves live
/// references immediately before writing, never carrying a possibly-stale
/// `Zone`/`Task` object through the cascade computation itself.
class ZoneMove {
  const ZoneMove({
    required this.zoneId,
    required this.newStartMinutes,
    required this.newEndMinutes,
    required this.taskMoves,
  });

  final String zoneId;
  final int newStartMinutes;
  final int newEndMinutes;

  /// Every task assigned to this zone (`Task.zoneId == zoneId`), shifted
  /// by the SAME delta this zone itself moved — confirmed via
  /// AskUserQuestion: a zone's contents move with it as one unit,
  /// uniformly whether this zone is the one the user dragged or one
  /// pushed by the cascade chain. Empty when this zone has no assigned
  /// tasks, or when the caller passed none in (see
  /// [computeZoneCascadeMoves]'s own `tasksByZoneId` parameter).
  final List<ZoneTaskMove> taskMoves;
}

/// A task moving because the zone it's assigned to moved — deliberately a
/// SEPARATE type from [TaskMove] (`cascade_reschedule.dart`), not a reused
/// one: that type's `newScheduledAt` is a full `DateTime` on a specific
/// day, matching the ordinary task-cascade's own inputs, while a zone
/// operates in minutes-since-midnight with no date at all (see
/// `Zone.startMinutes`'s own doc comment) — the caller resolves this
/// against whichever day it's actually applying the write to.
class ZoneTaskMove {
  const ZoneTaskMove({required this.taskId, required this.deltaMinutes});

  final String taskId;
  final int deltaMinutes;
}

/// Zone-to-zone cascade — requested directly: "zones should never
/// overlap... perhaps cascading... that doesn't block user intention."
/// Structurally mirrors [computeCascadeMoves]'s own nearest-edge-push/
/// chain/day-boundary-abort algorithm (see that function's extensive doc
/// comment for the worked derivation this shares), adapted to Zone's
/// minutes-since-midnight representation and Zone's own additional
/// "carries its assigned tasks along" rule confirmed via AskUserQuestion.
///
/// [zoneStartOverride]/[zoneEndOverride] describe the DRAGGED zone's own
/// new window — for a MOVE, both change by the same delta (the block's
/// whole duration is preserved); for a RESIZE, only one changes (the
/// un-dragged edge is passed through unchanged) — confirmed via
/// AskUserQuestion that resize's push direction is determined by which
/// edge grew (never computed via nearest-edge the way move's is), which
/// falls out of this shared algorithm for free: the un-moved edge simply
/// never overlaps anything on its own side, so only the grown edge's
/// side ever produces a push candidate.
///
/// [otherZones] is every OTHER zone in the day (never includes the
/// dragged one) at its CURRENT window. [tasksByZoneId] maps each zone id
/// (dragged or other) to its own currently-assigned tasks — used only to
/// compute each [ZoneMove]'s own [ZoneMove.taskMoves], never to affect
/// which zones get pushed or in which direction (task assignment is
/// metadata riding along, per CONSTITUTION.md's "Zone is metadata on a
/// Task, not a container that owns it," not a constraint on the zone
/// cascade itself).
///
/// Returns null when the chain can't be satisfied within one day
/// (0-1440 minutes) — the caller's signal to snap back as if the
/// gesture never happened, nothing partially applied, same contract as
/// [computeCascadeMoves].
List<ZoneMove>? computeZoneCascadeMoves({
  required String draggedZoneId,
  required int draggedZoneOriginalStartMinutes,
  required int zoneStartOverride,
  required int zoneEndOverride,
  required List<Zone> otherZones,
  required Map<String, List<Task>> tasksByZoneId,
}) {
  const dayStart = 0;
  const dayEnd = 24 * 60;

  if (zoneStartOverride < dayStart || zoneEndOverride > dayEnd) return null;
  if (zoneEndOverride <= zoneStartOverride) return null;

  // Working slot table: zoneId -> (start, end), seeded with every other
  // zone at its current window, plus the dragged zone at its proposed one.
  final slots = <String, (int start, int end)>{
    for (final zone in otherZones)
      zone.id: (zone.startMinutes, zone.endMinutes),
  };
  slots[draggedZoneId] = (zoneStartOverride, zoneEndOverride);

  // zoneId -> ORIGINAL start, before this cascade — needed at the end to
  // compute each zone's own NET delta for [ZoneMove.taskMoves] (a zone
  // pushed more than once in one chain must report one net shift, not one
  // per intermediate push). The dragged zone's original start is supplied
  // directly by the caller ([draggedZoneOriginalStartMinutes]) rather than
  // looked up here, since [otherZones] deliberately never includes it.
  final originalStart = <String, int>{
    for (final zone in otherZones) zone.id: zone.startMinutes,
    draggedZoneId: draggedZoneOriginalStartMinutes,
  };
  final visited = <String>{draggedZoneId};
  final pending = <String>[draggedZoneId];
  final finalWindow = <String, (int start, int end)>{
    draggedZoneId: (zoneStartOverride, zoneEndOverride),
  };

  final maxChainLength = otherZones.length + 1;

  while (pending.isNotEmpty) {
    if (visited.length > maxChainLength) return null;

    final moverId = pending.removeAt(0);
    final (moverStart, moverEnd) = slots[moverId]!;

    final earlierPushes = <Zone>[];
    final laterPushes = <Zone>[];
    for (final other in otherZones) {
      if (visited.contains(other.id)) continue;
      final (otherStart, otherEnd) = slots[other.id]!;
      final overlaps = moverStart < otherEnd && otherStart < moverEnd;
      if (!overlaps) continue;

      final distanceToEnd = (moverStart - otherEnd).abs();
      final distanceToStart = (moverStart - otherStart).abs();
      if (distanceToEnd <= distanceToStart) {
        earlierPushes.add(other);
      } else {
        laterPushes.add(other);
      }
    }

    earlierPushes.sort((a, b) => slots[b.id]!.$2.compareTo(slots[a.id]!.$2));
    var earlierEdge = moverStart;
    for (final zone in earlierPushes) {
      final duration = slots[zone.id]!.$2 - slots[zone.id]!.$1;
      final placed =
          _findFreeSlot(
            slots,
            visited,
            zoneId: zone.id,
            edge: earlierEdge,
            duration: duration,
            searchEarlier: true,
            dayStart: dayStart,
            dayEnd: dayEnd,
          ) ??
          _findFreeSlot(
            slots,
            visited,
            zoneId: zone.id,
            edge: moverEnd,
            duration: duration,
            searchEarlier: false,
            dayStart: dayStart,
            dayEnd: dayEnd,
          );
      if (placed == null) return null;

      slots[zone.id] = placed;
      finalWindow[zone.id] = placed;
      visited.add(zone.id);
      pending.add(zone.id);
      earlierEdge = placed.$1;
    }

    laterPushes.sort((a, b) => slots[a.id]!.$1.compareTo(slots[b.id]!.$1));
    var laterEdge = moverEnd;
    for (final zone in laterPushes) {
      final duration = slots[zone.id]!.$2 - slots[zone.id]!.$1;
      final placed =
          _findFreeSlot(
            slots,
            visited,
            zoneId: zone.id,
            edge: laterEdge,
            duration: duration,
            searchEarlier: false,
            dayStart: dayStart,
            dayEnd: dayEnd,
          ) ??
          _findFreeSlot(
            slots,
            visited,
            zoneId: zone.id,
            edge: moverStart,
            duration: duration,
            searchEarlier: true,
            dayStart: dayStart,
            dayEnd: dayEnd,
          );
      if (placed == null) return null;

      slots[zone.id] = placed;
      finalWindow[zone.id] = placed;
      visited.add(zone.id);
      pending.add(zone.id);
      laterEdge = placed.$2;
    }

    if (visited.length > maxChainLength) return null;
  }

  return [
    for (final entry in finalWindow.entries)
      ZoneMove(
        zoneId: entry.key,
        newStartMinutes: entry.value.$1,
        newEndMinutes: entry.value.$2,
        taskMoves: [
          for (final task in tasksByZoneId[entry.key] ?? const <Task>[])
            ZoneTaskMove(
              taskId: task.id,
              deltaMinutes: entry.value.$1 - originalStart[entry.key]!,
            ),
        ],
      ),
  ];
}

(int, int)? _findFreeSlot(
  Map<String, (int, int)> slots,
  Set<String> visited, {
  required String zoneId,
  required int edge,
  required int duration,
  required bool searchEarlier,
  required int dayStart,
  required int dayEnd,
}) {
  var start = searchEarlier ? edge - duration : edge;
  var end = start + duration;

  while (true) {
    if (start < dayStart || end > dayEnd) return null;

    final collision = _firstOccupiedOverlap(
      slots,
      visited,
      excludeId: zoneId,
      start: start,
      end: end,
    );
    if (collision == null) return (start, end);

    if (searchEarlier) {
      end = collision.$1;
      start = end - duration;
    } else {
      start = collision.$2;
      end = start + duration;
    }
  }
}

(int, int)? _firstOccupiedOverlap(
  Map<String, (int, int)> slots,
  Set<String> visited, {
  required String excludeId,
  required int start,
  required int end,
}) {
  for (final id in visited) {
    if (id == excludeId) continue;
    final (occupiedStart, occupiedEnd) = slots[id]!;
    if (start < occupiedEnd && occupiedStart < end) {
      return (occupiedStart, occupiedEnd);
    }
  }
  return null;
}
