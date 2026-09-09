import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_cascade_reschedule.dart';

void main() {
  Zone zone(String id, int start, int end) =>
      Zone(id: id, title: id, startMinutes: start, endMinutes: end);

  Task task(String id, String? zoneId, {int scheduledMinutes = 0}) => Task(
    id: id,
    title: id,
    zoneId: zoneId,
    scheduledAt: DateTime(2026, 8, 20, 0, scheduledMinutes),
    durationMinutes: 15,
    categoryId: BuiltInCategoryIds.work,
    schemaVersion: 1,
  );

  group('computeZoneCascadeMoves', () {
    test('no overlap at all returns just the dragged zone\'s own move', () {
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [zone('b', 13 * 60, 14 * 60)],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      expect(moves!.map((m) => m.zoneId), ['a']);
      expect(moves.single.newStartMinutes, 9 * 60 + 30);
      expect(moves.single.newEndMinutes, 10 * 60 + 30);
    });

    test('back-to-back (touching) windows are not treated as an overlap', () {
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60,
        zoneEndOverride: 10 * 60,
        otherZones: [zone('b', 10 * 60, 11 * 60)],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      expect(moves!.map((m) => m.zoneId), ['a']);
    });

    test('dragging zone A later into zone B pushes B later, keeping its own '
        'duration', () {
      // A: 9-10, dragged to 9:30-10:30. B: 10-11 (60min). A's new start
      // (9:30) is 30min from B's own start (10:00) and 60min from B's
      // own end (11:00) -> B's start is nearer -> B pushes LATER,
      // landing right after A's new end (10:30), keeping its 60min
      // duration: B becomes 10:30-11:30.
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [zone('b', 10 * 60, 11 * 60)],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      expect(byId['a']!.newStartMinutes, 9 * 60 + 30);
      expect(byId['b']!.newStartMinutes, 10 * 60 + 30);
      expect(byId['b']!.newEndMinutes, 11 * 60 + 30);
    });

    test('dragging zone A earlier into zone B pushes B earlier, keeping its '
        'own duration', () {
      // A: 10-11, dragged to 9-10. B: 8:30-9:30 (60min). A's new start
      // (9:00) is 30min from B's own end (9:30) and 30min from B's own
      // start... use asymmetric distances instead: B: 8:15-9:15. A's new
      // start (9:00) is 15min from B's end (9:15) and 45min from B's
      // start (8:15) -> B's end is nearer -> B pushes EARLIER, its own
      // end landing exactly on A's new start: B becomes 8:00-9:00.
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 10 * 60,
        zoneStartOverride: 9 * 60,
        zoneEndOverride: 10 * 60,
        otherZones: [zone('b', 8 * 60 + 15, 9 * 60 + 15)],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      expect(byId['b']!.newStartMinutes, 8 * 60);
      expect(byId['b']!.newEndMinutes, 9 * 60);
    });

    test('3-zone chain cascades in the push direction', () {
      // A dragged into B, B pushed into C, C pushed too.
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [
          zone('b', 10 * 60, 11 * 60),
          zone('c', 10 * 60 + 45, 11 * 60 + 45),
        ],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      expect(byId.keys, containsAll(['a', 'b', 'c']));
      // b lands right after a; c, still overlapping b's new slot, lands
      // right after b's new slot.
      expect(byId['b']!.newStartMinutes, 10 * 60 + 30);
      expect(byId['c']!.newStartMinutes, byId['b']!.newEndMinutes);
    });

    test('a push genuinely unsatisfiable in EITHER direction (the whole day '
        'packed solid) aborts the cascade — nothing partially applies', () {
      // The entire day (00:00-24:00) is filled edge-to-edge by three
      // 8-hour zones. Dragging the middle one even slightly overlaps
      // both its neighbours, and neither has anywhere left to go in
      // either direction — the day has no free minute anywhere.
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'b',
        draggedZoneOriginalStartMinutes: 8 * 60,
        zoneStartOverride: 8 * 60 - 30,
        zoneEndOverride: 16 * 60 - 30,
        otherZones: [zone('a', 0, 8 * 60), zone('c', 16 * 60, 24 * 60)],
        tasksByZoneId: const {},
      );

      expect(moves, isNull);
    });

    test('the dragged zone itself landing before 00:00 or after 24:00 is '
        'rejected outright', () {
      expect(
        computeZoneCascadeMoves(
          draggedZoneId: 'a',
          draggedZoneOriginalStartMinutes: 60,
          zoneStartOverride: -30,
          zoneEndOverride: 30,
          otherZones: const [],
          tasksByZoneId: const {},
        ),
        isNull,
      );
      expect(
        computeZoneCascadeMoves(
          draggedZoneId: 'a',
          draggedZoneOriginalStartMinutes: 23 * 60,
          zoneStartOverride: 23 * 60 + 45,
          zoneEndOverride: 24 * 60 + 30,
          otherZones: const [],
          tasksByZoneId: const {},
        ),
        isNull,
      );
    });

    test(
      'the dragged zone carries its own assigned tasks by the same delta',
      () {
        final t1 = task('t1', 'a');
        final t2 = task('t2', 'a');
        final moves = computeZoneCascadeMoves(
          draggedZoneId: 'a',
          draggedZoneOriginalStartMinutes: 9 * 60,
          zoneStartOverride: 9 * 60 + 45,
          zoneEndOverride: 10 * 60 + 45,
          otherZones: const [],
          tasksByZoneId: {
            'a': [t1, t2],
          },
        );

        expect(moves, isNotNull);
        final aMove = moves!.single;
        expect(aMove.taskMoves, hasLength(2));
        for (final taskMove in aMove.taskMoves) {
          expect(taskMove.deltaMinutes, 45);
        }
      },
    );

    test('a PUSHED zone (not the one dragged) also carries its own assigned '
        'tasks by its own net delta', () {
      final zoneTask = task('bTask', 'b');
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [zone('b', 10 * 60, 11 * 60)],
        tasksByZoneId: {
          'b': [zoneTask],
        },
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      // b pushed from 10:00 to 10:30 -> net delta +30 for its own task.
      expect(byId['b']!.taskMoves.single.taskId, 'bTask');
      expect(byId['b']!.taskMoves.single.deltaMinutes, 30);
    });

    test('a zone chained through MULTIPLE pushes reports one NET delta for '
        'its tasks, not one per intermediate push', () {
      final cTask = task('cTask', 'c');
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [
          zone('b', 10 * 60, 11 * 60),
          zone('c', 10 * 60 + 45, 11 * 60 + 45),
        ],
        tasksByZoneId: {
          'c': [cTask],
        },
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      // c's ORIGINAL start was 10:45; its final start is whatever landed
      // right after b's final end. The net delta is (final - original),
      // computed once, not summed across the chain.
      final expectedDelta = byId['c']!.newStartMinutes - (10 * 60 + 45);
      expect(byId['c']!.taskMoves.single.deltaMinutes, expectedDelta);
    });

    test('a zone with no assigned tasks in tasksByZoneId reports an empty '
        'taskMoves list, not an error', () {
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'a',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: const [],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      expect(moves!.single.taskMoves, isEmpty);
    });

    test('RESIZE shape: only the bottom edge grows later, the top edge is '
        'passed through unchanged, and only a zone starting after the OLD '
        'end can be pushed', () {
      // Zone B resized: top edge unchanged at 9:00, bottom edge grows
      // from 10:00 to 10:30 -> overlaps zone C (10:15-11:00), which
      // pushes later.
      final moves = computeZoneCascadeMoves(
        draggedZoneId: 'b',
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [
          zone('a', 7 * 60, 8 * 60 + 30),
          zone('c', 10 * 60 + 15, 11 * 60),
        ],
        tasksByZoneId: const {},
      );

      expect(moves, isNotNull);
      final byId = {for (final m in moves!) m.zoneId: m};
      // a (well before b's window) is never touched at all.
      expect(byId.containsKey('a'), isFalse);
      expect(byId['b']!.newStartMinutes, 9 * 60);
      expect(byId['b']!.newEndMinutes, 10 * 60 + 30);
      // c pushed later, landing right after b's new (grown) end.
      expect(byId['c']!.newStartMinutes, 10 * 60 + 30);
    });
  });
}
