import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/services/zone_cascade_reschedule.dart';

import '../../support/fake_notification_service.dart';

void main() {
  late Box<Zone> box;
  late Box<Task> taskBox;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_providers');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Zone>('test_zones_$stamp');
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');

    container = ProviderContainer(
      overrides: [
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(box)),
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
    await taskBox.deleteFromDisk();
  });

  group('dev-only clear tools', () {
    test('clearAllZones deletes every zone', () async {
      final notifier = container.read(zoneListProvider.notifier);
      await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      await notifier.createZone(
        title: 'Evening wind-down',
        startMinutes: 21 * 60,
        endMinutes: 22 * 60,
      );
      expect(container.read(zoneListProvider), hasLength(2));

      await notifier.clearAllZones();

      expect(container.read(zoneListProvider), isEmpty);
      expect(container.read(zoneRepositoryProvider).getAll(), isEmpty);
    });
  });

  group('materialization', () {
    test('createZone with a recurrenceRule materializes the rest of the '
        'window immediately, not only at next launch', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final anchor = DateTime(2026, 8, 3); // Monday

      final template = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        anchorDateForRecurrence: anchor,
      );

      expect(template.isRecurrenceTemplate, isTrue);
      final zones = container.read(zoneListProvider);
      // 8-week window (default), one row per day including the template.
      expect(zones.length, greaterThan(1));
      expect(
        zones.every((z) => z.recurrenceId == template.recurrenceId),
        isTrue,
      );
    });

    test('createZone without a recurrenceRule stays a single dateless row '
        '— unaffected, matches the confirmed non-recurring shape', () async {
      final notifier = container.read(zoneListProvider.notifier);

      await notifier.createZone(
        title: 'Work',
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
      );

      final zones = container.read(zoneListProvider);
      expect(zones, hasLength(1));
      expect(zones.single.anchorDate, isNull);
      expect(zones.single.isRecurring, isFalse);
    });

    test('materializeDueRecurrences tops up every template\'s series and is '
        'idempotent on repeat calls', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final anchor = DateTime(2026, 8, 3);

      final template = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        anchorDateForRecurrence: anchor,
      );
      final afterCreate = container.read(zoneListProvider).length;

      await notifier.materializeDueRecurrences();
      expect(container.read(zoneListProvider).length, afterCreate);

      // Deleting one materialized instance and re-running tops it back up
      // — same "repeatable, idempotent" contract as Task's own version.
      final anInstance = container
          .read(zoneListProvider)
          .firstWhere((z) => z.id != template.id);
      await notifier.deleteZone(anInstance.id);
      expect(container.read(zoneListProvider).length, afterCreate - 1);

      await notifier.materializeDueRecurrences();
      expect(container.read(zoneListProvider).length, afterCreate);
    });
  });

  group('deleteZone', () {
    test('cancels the deleted zone\'s notification alongside removing it '
        '— confirmed via FakeNotificationService not throwing', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = await notifier.createZone(
        title: 'Evening wind-down',
        startMinutes: 21 * 60,
        endMinutes: 22 * 60,
      );

      await notifier.deleteZone(zone.id);

      expect(container.read(zoneListProvider), isEmpty);
    });
  });

  group('importZones', () {
    test('a new zone (id not previously seen) is imported', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = Zone.create(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );

      final result = await notifier.importZones([zone]);

      expect(result.imported, 1);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 0);
      expect(container.read(zoneRepositoryProvider).getById(zone.id), zone);
    });

    test('an identical zone (same id, same fields) counts as already '
        'present and is not rewritten', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final reimported = Zone(
        id: zone.id,
        title: zone.title,
        startMinutes: zone.startMinutes,
        endMinutes: zone.endMinutes,
      );

      final result = await notifier.importZones([reimported]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 1);
      expect(result.conflicts, 0);
    });

    test('a same-id zone with DIFFERENT fields counts as a conflict and is '
        'left completely untouched — never silently overwritten', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final conflicting = Zone(
        id: zone.id,
        title: 'Renamed elsewhere',
        startMinutes: zone.startMinutes,
        endMinutes: zone.endMinutes,
      );

      final result = await notifier.importZones([conflicting]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 1);
      expect(
        container.read(zoneRepositoryProvider).getById(zone.id)?.title,
        'Morning ritual',
      );
    });
  });

  group('commitZoneCascade', () {
    test('writes every zone\'s new window from a computed cascade', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final a = await notifier.createZone(
        title: 'A',
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );
      final b = await notifier.createZone(
        title: 'B',
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
      );

      final moves = computeZoneCascadeMoves(
        draggedZoneId: a.id,
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [b],
        tasksByZoneId: const {},
      )!;

      await notifier.commitZoneCascade(moves);

      final zones = container.read(zoneListProvider);
      final savedA = zones.firstWhere((z) => z.id == a.id);
      final savedB = zones.firstWhere((z) => z.id == b.id);
      expect(savedA.startMinutes, 9 * 60 + 30);
      expect(savedA.endMinutes, 10 * 60 + 30);
      expect(savedB.startMinutes, 10 * 60 + 30);
      expect(savedB.endMinutes, 11 * 60 + 30);
    });

    test('shifts every zone\'s assigned tasks by the same combined batch — '
        'taskListProvider reflects it without a manual reload', () async {
      final zoneNotifier = container.read(zoneListProvider.notifier);
      final taskNotifier = container.read(taskListProvider.notifier);

      final a = await zoneNotifier.createZone(
        title: 'A',
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );
      final b = await zoneNotifier.createZone(
        title: 'B',
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
      );
      final taskInA = await taskNotifier.createTask(
        title: 'In A',
        scheduledAt: DateTime(2026, 8, 20, 9, 15),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      taskInA.zoneId = a.id;
      await taskNotifier.updateTask(taskInA);
      final taskInB = await taskNotifier.createTask(
        title: 'In B',
        scheduledAt: DateTime(2026, 8, 20, 10, 15),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      taskInB.zoneId = b.id;
      await taskNotifier.updateTask(taskInB);

      final moves = computeZoneCascadeMoves(
        draggedZoneId: a.id,
        draggedZoneOriginalStartMinutes: 9 * 60,
        zoneStartOverride: 9 * 60 + 30,
        zoneEndOverride: 10 * 60 + 30,
        otherZones: [b],
        tasksByZoneId: {
          a.id: [taskInA],
          b.id: [taskInB],
        },
      )!;

      await zoneNotifier.commitZoneCascade(moves);

      final tasks = container.read(taskListProvider);
      final savedTaskInA = tasks.firstWhere((t) => t.id == taskInA.id);
      final savedTaskInB = tasks.firstWhere((t) => t.id == taskInB.id);
      expect(savedTaskInA.scheduledAt, DateTime(2026, 8, 20, 9, 45));
      expect(savedTaskInB.scheduledAt, DateTime(2026, 8, 20, 10, 45));
      expect(savedTaskInA.status, TaskStatus.rescheduled);
      expect(savedTaskInB.status, TaskStatus.rescheduled);
    });

    test('a zoneId with no matching zone (already deleted) is silently '
        'skipped, other zones in the cascade still apply', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final b = await notifier.createZone(
        title: 'B',
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
      );

      await notifier.commitZoneCascade([
        const ZoneMove(
          zoneId: 'no-such-zone',
          newStartMinutes: 0,
          newEndMinutes: 60,
          taskMoves: [],
        ),
        ZoneMove(
          zoneId: b.id,
          newStartMinutes: 10 * 60 + 30,
          newEndMinutes: 11 * 60 + 30,
          taskMoves: const [],
        ),
      ]);

      final saved = container
          .read(zoneListProvider)
          .firstWhere((z) => z.id == b.id);
      expect(saved.startMinutes, 10 * 60 + 30);
    });
  });
}
