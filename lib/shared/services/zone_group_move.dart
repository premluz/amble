import '../models/task.dart';
import '../models/zone.dart';
import 'zone_cascade_reschedule.dart';

/// One day-column's worth of a group gesture — the unit
/// [computeZoneGroupMoves] resolves independently.
///
/// A weekly grid selection can span several days at once, but
/// [computeZoneCascadeMoves] reasons about ONE day: zones carry
/// minutes-since-midnight with no date (see `Zone.startMinutes`), and the
/// Timeline's own `_commitZoneCascade` already takes a `day` parameter and
/// filters its candidate set to that day's members. So a group gesture is
/// resolved per column and then combined, rather than by teaching the
/// cascade about dates.
class ZoneGroupColumn {
  const ZoneGroupColumn({
    required this.day,
    required this.selectedZones,
    required this.otherZones,
  });

  /// The calendar day this column represents.
  final DateTime day;

  /// The SELECTED zones that apply on [day], each at its current window.
  final List<Zone> selectedZones;

  /// Every other zone that applies on [day] — the cascade's push
  /// candidates. Never includes anything from [selectedZones].
  final List<Zone> otherZones;
}

/// Why a group move/resize was refused, for the caller to surface.
enum ZoneGroupFailure {
  /// A member would leave the day (before 00:00 / after 24:00), or its
  /// own edges would cross.
  outOfDay,

  /// The zone-to-zone cascade could not place every pushed zone within
  /// the day — [computeZoneCascadeMoves] returned null for some column.
  cascadeUnsatisfiable,
}

/// The outcome of a group gesture: either every column resolved, or the
/// whole gesture is refused.
class ZoneGroupMoveResult {
  const ZoneGroupMoveResult.success(this.moves) : failure = null;
  const ZoneGroupMoveResult.refused(this.failure) : moves = const [];

  /// Every zone's new window, across every column, ready to hand to
  /// `ZoneList.commitZoneCascade` in ONE call.
  final List<ZoneMove> moves;

  /// Non-null when nothing should be written at all.
  final ZoneGroupFailure? failure;

  bool get isSuccess => failure == null;
}

/// Which edge(s) a group gesture moves.
enum ZoneGroupGestureKind {
  /// Both edges shift by the same delta — duration preserved.
  move,

  /// The START moves, the END stays anchored.
  resizeTop,

  /// The END moves, the START stays anchored.
  resizeBottom,
}

/// Applies one group move/resize across every day-column a selection spans,
/// enforcing zone-to-zone non-overlap independently per column.
///
/// **All-or-nothing across the WHOLE selection, not per column** — a
/// judgment call, flagged in docs/DECISIONS.md. [computeZoneCascadeMoves]
/// already refuses wholesale rather than partially applying, on the
/// reasoning that a half-applied cascade is worse than a refused drag; the
/// same argument is stronger here, because a partially-applied group would
/// leave a multi-day selection silently inconsistent across columns — the
/// user would have to inspect each day to discover which ones took. So if
/// ANY column cannot satisfy non-overlap, nothing is written anywhere.
///
/// **Capacity is deliberately NOT checked here**, per CONSTITUTION.md's
/// "capacity is checked, not enforced physically": a zone whose assigned
/// tasks exceed its own duration is allowed, and surfaced in the capacity
/// indicator rather than blocked. Non-overlap is a genuine structural
/// invariant ("Zones cannot overlap each other"); capacity is not.
///
/// [deltaMinutes] is the already-snapped delta the gesture resolved to.
/// Every selected zone in every column receives the SAME delta — matching
/// the task group-gesture rule ("the same raw delta to every member"),
/// with each member independently clamped by the constraints below.
ZoneGroupMoveResult computeZoneGroupMoves({
  required List<ZoneGroupColumn> columns,
  required int deltaMinutes,
  required ZoneGroupGestureKind kind,
  required Map<String, List<Task>> tasksByZoneId,
  int minDurationMinutes = 5,
}) {
  if (deltaMinutes == 0) return const ZoneGroupMoveResult.success([]);

  final all = <ZoneMove>[];

  for (final column in columns) {
    if (column.selectedZones.isEmpty) continue;

    // Resolve this column one selected zone at a time, threading the
    // result forward: a column with two selected zones must see the
    // FIRST one's new window when placing the second, or they could be
    // pushed onto each other.
    var others = List<Zone>.of(column.otherZones);
    final columnMoves = <ZoneMove>[];

    for (final zone in column.selectedZones) {
      final (newStart, newEnd) = _applyDelta(
        zone: zone,
        deltaMinutes: deltaMinutes,
        kind: kind,
      );

      if (newStart < 0 || newEnd > 24 * 60) {
        return const ZoneGroupMoveResult.refused(ZoneGroupFailure.outOfDay);
      }
      if (newEnd - newStart < minDurationMinutes) {
        return const ZoneGroupMoveResult.refused(ZoneGroupFailure.outOfDay);
      }

      final moves = computeZoneCascadeMoves(
        draggedZoneId: zone.id,
        draggedZoneOriginalStartMinutes: zone.startMinutes,
        zoneStartOverride: newStart,
        zoneEndOverride: newEnd,
        otherZones: others,
        tasksByZoneId: tasksByZoneId,
      );
      if (moves == null) {
        return const ZoneGroupMoveResult.refused(
          ZoneGroupFailure.cascadeUnsatisfiable,
        );
      }

      columnMoves.addAll(moves);

      // Thread this zone's committed window (and anything it pushed)
      // forward, so the next selected zone in the same column plans
      // against reality rather than the pre-gesture layout.
      final movedById = {for (final move in moves) move.zoneId: move};
      others = [
        for (final other in others)
          if (movedById[other.id] case final moved?)
            _withWindow(other, moved.newStartMinutes, moved.newEndMinutes)
          else
            other,
        _withWindow(zone, newStart, newEnd),
      ];
    }

    all.addAll(columnMoves);
  }

  return ZoneGroupMoveResult.success(_dedupeLastWins(all));
}

(int, int) _applyDelta({
  required Zone zone,
  required int deltaMinutes,
  required ZoneGroupGestureKind kind,
}) {
  return switch (kind) {
    ZoneGroupGestureKind.move => (
      zone.startMinutes + deltaMinutes,
      zone.endMinutes + deltaMinutes,
    ),
    ZoneGroupGestureKind.resizeTop => (
      zone.startMinutes + deltaMinutes,
      zone.endMinutes,
    ),
    ZoneGroupGestureKind.resizeBottom => (
      zone.startMinutes,
      zone.endMinutes + deltaMinutes,
    ),
  };
}

/// A detached copy carrying a different window — never persisted, only
/// used to plan the next zone in the same column against this one's
/// proposed position. Deliberately does NOT mutate the real row: the
/// cascade is computed in full before anything is written.
Zone _withWindow(Zone zone, int startMinutes, int endMinutes) => Zone(
  id: zone.id,
  title: zone.title,
  startMinutes: startMinutes,
  endMinutes: endMinutes,
  schemaVersion: zone.schemaVersion,
  recurrenceRule: zone.recurrenceRule,
  notificationsEnabled: zone.notificationsEnabled,
  recurrenceId: zone.recurrenceId,
  anchorDate: zone.anchorDate,
);

/// One zone can be touched twice within a column (moved as a selected
/// member, then pushed again while planning a later member). The LAST
/// window computed is the real one — earlier entries are intermediate
/// states that were already superseded before anything was written.
List<ZoneMove> _dedupeLastWins(List<ZoneMove> moves) {
  final byId = <String, ZoneMove>{};
  for (final move in moves) {
    byId[move.zoneId] = move;
  }
  return byId.values.toList();
}
