import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_group_move.dart';

/// Group move/resize for a MULTI-ZONE selection spanning several days —
/// the Weekly Zone Authoring Grid's own editing path.
///
/// The thing under test that nothing else covers: a selection can span
/// day-columns, but `computeZoneCascadeMoves` reasons about ONE day (zones
/// are minutes-since-midnight with no date). So this resolves each column
/// independently and then refuses the WHOLE gesture if any column can't
/// satisfy zone-to-zone non-overlap — see the service's own doc comment
/// and docs/DECISIONS.md for why all-or-nothing rather than per-column.
void main() {
  Zone zone(String id, int start, int end, {DateTime? anchorDate}) => Zone(
    id: id,
    title: id,
    startMinutes: start,
    endMinutes: end,
    anchorDate: anchorDate,
  );

  final monday = DateTime(2026, 9, 14);
  final tuesday = DateTime(2026, 9, 15);

  group('computeZoneGroupMoves', () {
    test('a zero delta writes nothing at all', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('a', 9 * 60, 10 * 60)],
            otherZones: const [],
          ),
        ],
        deltaMinutes: 0,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isTrue);
      expect(result.moves, isEmpty);
    });

    test('moves every selected zone across every column by the same delta', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('mon', 9 * 60, 10 * 60, anchorDate: monday)],
            otherZones: const [],
          ),
          ZoneGroupColumn(
            day: tuesday,
            selectedZones: [zone('tue', 14 * 60, 15 * 60, anchorDate: tuesday)],
            otherZones: const [],
          ),
        ],
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isTrue);
      final byId = {for (final m in result.moves) m.zoneId: m};
      expect(byId['mon']!.newStartMinutes, 9 * 60 + 30);
      expect(byId['mon']!.newEndMinutes, 10 * 60 + 30);
      // The SAME delta, applied independently in its own column — a
      // Tuesday zone is not affected by Monday's own neighbours.
      expect(byId['tue']!.newStartMinutes, 14 * 60 + 30);
      expect(byId['tue']!.newEndMinutes, 15 * 60 + 30);
    });

    test('a move preserves duration; resizes move only their own edge', () {
      ZoneGroupMoveResult run(ZoneGroupGestureKind kind) =>
          computeZoneGroupMoves(
            columns: [
              ZoneGroupColumn(
                day: monday,
                selectedZones: [zone('a', 9 * 60, 10 * 60)],
                otherZones: const [],
              ),
            ],
            deltaMinutes: 15,
            kind: kind,
            tasksByZoneId: const {},
          );

      final moved = run(ZoneGroupGestureKind.move).moves.single;
      expect(moved.newStartMinutes, 9 * 60 + 15);
      expect(moved.newEndMinutes, 10 * 60 + 15);

      final top = run(ZoneGroupGestureKind.resizeTop).moves.single;
      expect(top.newStartMinutes, 9 * 60 + 15);
      expect(top.newEndMinutes, 10 * 60, reason: 'END stays anchored');

      final bottom = run(ZoneGroupGestureKind.resizeBottom).moves.single;
      expect(bottom.newStartMinutes, 9 * 60, reason: 'START stays anchored');
      expect(bottom.newEndMinutes, 10 * 60 + 15);
    });

    test('pushes a non-selected neighbour out of the way within a column', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('a', 9 * 60, 10 * 60)],
            // Directly in the path of a +30 move.
            otherZones: [zone('b', 10 * 60, 11 * 60)],
          ),
        ],
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isTrue);
      final byId = {for (final m in result.moves) m.zoneId: m};
      expect(byId.containsKey('b'), isTrue, reason: 'neighbour was pushed');
      expect(
        byId['b']!.newStartMinutes,
        greaterThanOrEqualTo(byId['a']!.newEndMinutes),
        reason: 'the pushed zone must not overlap the moved one',
      );
    });

    test('REFUSES THE WHOLE GESTURE when any single column cannot satisfy '
        'non-overlap — no column writes, not even the ones that resolved', () {
      final result = computeZoneGroupMoves(
        columns: [
          // Monday resolves fine on its own.
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('mon', 9 * 60, 10 * 60)],
            otherZones: const [],
          ),
          // Tuesday cannot: the selected zone is boxed in by immovable
          // neighbours filling the rest of the day.
          ZoneGroupColumn(
            day: tuesday,
            selectedZones: [zone('tue', 10 * 60, 11 * 60)],
            otherZones: [
              zone('before', 0, 10 * 60),
              zone('after', 11 * 60, 24 * 60),
            ],
          ),
        ],
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, ZoneGroupFailure.cascadeUnsatisfiable);
      expect(
        result.moves,
        isEmpty,
        reason:
            'all-or-nothing: a partially-applied week would leave the '
            'selection silently inconsistent across columns',
      );
    });

    test('refuses a gesture that would carry a member out of the day', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('late', 23 * 60, 24 * 60)],
            otherZones: const [],
          ),
        ],
        deltaMinutes: 60,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, ZoneGroupFailure.outOfDay);
      expect(result.moves, isEmpty);
    });

    test('refuses a resize that would collapse a zone below its minimum', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [zone('a', 9 * 60, 9 * 60 + 30)],
            otherZones: const [],
          ),
        ],
        // Dragging the top edge down past the bottom one.
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.resizeTop,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, ZoneGroupFailure.outOfDay);
    });

    test('two selected zones in ONE column plan against each other, not just '
        'against the pre-gesture layout', () {
      // Both selected, both moving +30 into a column where they would
      // otherwise be planned independently and could collide.
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: [
              zone('first', 9 * 60, 10 * 60),
              zone('second', 10 * 60, 11 * 60),
            ],
            otherZones: const [],
          ),
        ],
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isTrue);
      final byId = {for (final m in result.moves) m.zoneId: m};
      // Each zone appears exactly once in the final result, even though
      // planning touched them more than once.
      expect(
        result.moves.length,
        result.moves.map((m) => m.zoneId).toSet().length,
      );
      expect(byId['first']!.newStartMinutes, 9 * 60 + 30);
      expect(
        byId['second']!.newStartMinutes,
        greaterThanOrEqualTo(byId['first']!.newEndMinutes),
        reason: 'the two selected zones must not end up overlapping',
      );
    });

    test('a column with no selected zones is skipped entirely', () {
      final result = computeZoneGroupMoves(
        columns: [
          ZoneGroupColumn(
            day: monday,
            selectedZones: const [],
            otherZones: [zone('bystander', 9 * 60, 10 * 60)],
          ),
        ],
        deltaMinutes: 30,
        kind: ZoneGroupGestureKind.move,
        tasksByZoneId: const {},
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.moves,
        isEmpty,
        reason: 'an untouched column must never write its bystanders',
      );
    });
  });
}
