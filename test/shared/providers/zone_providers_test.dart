import 'package:amble/shared/providers/zone_facet_providers.dart';
import '../../support/memory_zone_repositories.dart';
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
        zoneFacetRepositoryProvider.overrideWithValue(MemoryZoneFacetRepository()),
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

  group('weekly creation', () {
    test('daily input produces seven weekly placements without materialization', () async {
      final notifier=container.read(zoneListProvider.notifier);
      await notifier.createZone(title:'Work',startMinutes:540,endMinutes:600,
        recurrenceRule:RecurrenceRule(frequency:RecurrenceFrequency.daily));
      final zones=container.read(zoneListProvider);
      expect(zones,hasLength(7)); expect(zones.every((z)=>z.isWeeklyPlacement),isTrue);
      await notifier.deleteZone(zones.first.id);
      await notifier.materializeDueRecurrences();
      expect(container.read(zoneListProvider).where((z)=>!z.archived),hasLength(6));
    });
    test('single-day input uses its explicit weekday', () async {
      final zone=await container.read(zoneListProvider.notifier).createZone(title:'Work',startMinutes:540,endMinutes:600,
        anchorDateForRecurrence:DateTime(2026,9,16));
      expect(zone.weekday,DateTime.wednesday); expect(zone.recurrenceRule,isNull);
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

      expect(container.read(zoneListProvider).where((z)=>!z.archived), isEmpty);
      expect(container.read(zoneRepositoryProvider).getById(zone.id), isNotNull);
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
      final reimported = Zone.fromJson(zone.toJson());

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

    test('editing weekly placements never reschedules dated tasks', () async {
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
      expect(savedTaskInA.scheduledAt, DateTime(2026, 8, 20, 9, 15));
      expect(savedTaskInB.scheduledAt, DateTime(2026, 8, 20, 10, 15));
      expect(savedTaskInA.status, TaskStatus.pending);
      expect(savedTaskInB.status, TaskStatus.pending);
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

  group('repairDuplicateZoneSeries', () {
    test('collapses duplicate same-titled series to the template-bearing one '
        'and is idempotent', () async {
      final repository = container.read(zoneRepositoryProvider);
      final notifier = container.read(zoneListProvider.notifier);
      final anchor = DateTime(2026, 8, 3);

      // Two parallel series for one title, exactly the shape the real
      // backup had — built directly through the repository so the now
      // fixed `createZone` can't collapse them before the repair runs.
      Zone member(String seriesId, int dayOffset, {bool template = false}) =>
          Zone.create(
            title: 'Morning ritual',
            startMinutes: 7 * 60,
            endMinutes: 8 * 60,
            recurrenceId: seriesId,
            anchorDate: anchor.add(Duration(days: dayOffset)),
            recurrenceRule: template
                ? RecurrenceRule(frequency: RecurrenceFrequency.daily)
                : null,
          );

      await repository.save(member('series-a', 0, template: true));
      await repository.save(member('series-a', 1));
      await repository.save(member('series-a', 2));
      // The loser: MORE rows, but no template — the tie-break must
      // still prefer the template-bearing series, since a series with
      // no template can never regenerate.
      await repository.save(member('series-b', 0));
      await repository.save(member('series-b', 1));
      await repository.save(member('series-b', 2));
      await repository.save(member('series-b', 3));
      // An unrelated standalone row, which must survive untouched.
      final standalone = Zone.create(
        title: 'Standalone',
        startMinutes: 12 * 60,
        endMinutes: 13 * 60,
      );
      await repository.save(standalone);

      await notifier.repairDuplicateZoneSeries();

      final after = container.read(zoneListProvider);
      expect(
        after.where((z) => z.recurrenceId == 'series-b'),
        isEmpty,
        reason: 'the non-canonical series is removed wholesale',
      );
      expect(after.where((z) => z.recurrenceId == 'series-a'), hasLength(3));
      expect(
        after.where((z) => z.id == standalone.id),
        hasLength(1),
        reason: 'non-recurring rows are never touched by the repair',
      );

      // Running it again changes nothing.
      final countAfterFirst = after.length;
      await notifier.repairDuplicateZoneSeries();
      expect(container.read(zoneListProvider), hasLength(countAfterFirst));
    });

    test('detaches an orphaned series (rows with a recurrenceId but no '
        'template) into plain standalone rows', () async {
      final repository = container.read(zoneRepositoryProvider);
      final notifier = container.read(zoneListProvider.notifier);
      final anchor = DateTime(2026, 8, 3);

      for (var i = 0; i < 3; i++) {
        await repository.save(
          Zone.create(
            title: 'Orphaned',
            startMinutes: 7 * 60,
            endMinutes: 8 * 60,
            recurrenceId: 'ghost-series',
            anchorDate: anchor.add(Duration(days: i)),
          ),
        );
      }

      await notifier.repairDuplicateZoneSeries();

      final after = container.read(zoneListProvider);
      expect(
        after,
        hasLength(3),
        reason: 'history is preserved — orphans are detached, not deleted',
      );
      expect(
        after.every((z) => z.recurrenceId == null),
        isTrue,
        reason:
            'a series with no template can never regenerate, so its rows '
            'become plain standalone zones rather than a half-alive series',
      );
    });

    test('leaves healthy data completely alone', () async {
      final notifier = container.read(zoneListProvider.notifier);
      await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        anchorDateForRecurrence: DateTime(2026, 8, 3),
      );
      final before = container.read(zoneListProvider).length;

      await notifier.repairDuplicateZoneSeries();

      expect(container.read(zoneListProvider), hasLength(before));
    });
  });

  group('deleteZoneSeries (orphan prevention)', () {
    test('deleting a series whose template is itself in the FUTURE detaches '
        'every surviving past row instead of orphaning them', () async {
      // Real bug, found by inspecting a user backup: 40 rows carried a
      // live `recurrenceId` with NO template anywhere in the series.
      // Nothing can ever regenerate such a series (the generator needs a
      // template), but every stranded row still renders on the grid
      // forever, reading as duplicate zones. It happened because the old
      // code only detached a template that survived in the PAST, and
      // said nothing about the template itself being deleted — which is
      // exactly what happens when the whole series is anchored today or
      // later.
      final notifier = container.read(zoneListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day);

      final template = Zone(id:'legacy-delete',title:'Morning ritual',startMinutes:420,endMinutes:480,
        recurrenceId:'legacy-delete',recurrenceRule:RecurrenceRule(frequency:RecurrenceFrequency.daily),anchorDate:anchor);
      await box.put(template.id,template);
      await notifier.materializeDueRecurrences();
      final seriesId = template.recurrenceId;
      expect(seriesId, isNotNull);

      // A row that predates the template — history, which the sweep
      // deliberately spares, and therefore the row at risk of being
      // orphaned once the template goes.
      final past = Zone.create(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceId: seriesId,
        anchorDate: anchor.subtract(const Duration(days: 3)),
      );
      await container.read(zoneRepositoryProvider).save(past);
      await notifier.materializeDueRecurrences();

      final instance = container
          .read(zoneListProvider)
          .firstWhere(
            (z) => z.recurrenceId == seriesId && z.anchorDate == anchor,
          );
      await notifier.deleteZoneSeries(instance);

      final leftovers = container
          .read(zoneListProvider)
          .where((z) => z.recurrenceId == seriesId)
          .toList();
      expect(
        leftovers,
        isEmpty,
        reason:
            'no row may keep a recurrenceId once its series has no '
            'template left — that is precisely the orphan state that '
            'renders as permanent duplicate zones',
      );

      final survivingPast = container
          .read(zoneListProvider)
          .where((z) => z.id == past.id)
          .firstOrNull;
      expect(
        survivingPast,
        isNotNull,
        reason: 'past rows are history and must still be preserved',
      );
      expect(survivingPast!.recurrenceRule, isNull);
    });
  });

  group('updateZoneSeries (the "affect future instances" re-anchor)', () {
    // A daily series anchored well in the past, so every generated
    // instance from "today" (real wall-clock `DateTime.now()`, which this
    // method reads directly) forward is unambiguously "future" regardless
    // of which real day this suite happens to run on.
    Future<Zone> createPastDailySeries(ZoneList notifier) async {
      final anchor=DateTime.now().subtract(const Duration(days:30));
      final template=Zone(id:'legacy-series',title:'Morning ritual',startMinutes:420,endMinutes:480,
        recurrenceId:'legacy-series',recurrenceRule:RecurrenceRule(frequency:RecurrenceFrequency.daily),
        anchorDate:DateTime(anchor.year,anchor.month,anchor.day));
      await box.put(template.id,template);
      await notifier.materializeDueRecurrences();
      return template;
    }

    test('moving ANY future instance re-anchors every future instance of the '
        'series to the new time', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final template = await createPastDailySeries(notifier);

      final todayStart = DateTime.now();
      final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
      final todaysInstance = container
          .read(zoneListProvider)
          .firstWhere(
            (z) =>
                z.recurrenceId == template.recurrenceId &&
                z.anchorDate != null &&
                z.anchorDate!.isAtSameMomentAs(today),
          );

      await notifier.updateZoneSeries(
        todaysInstance,
        newStartMinutes: 9 * 60,
        newEndMinutes: 10 * 60,
      );

      final seriesZones = container
          .read(zoneListProvider)
          .where((z) => z.recurrenceId == template.recurrenceId)
          .toList();
      final future = seriesZones.where(
        (z) => z.anchorDate != null && !z.anchorDate!.isBefore(today),
      );
      expect(future, isNotEmpty);
      for (final zone in future) {
        expect(zone.startMinutes, 9 * 60, reason: '${zone.anchorDate}');
        expect(zone.endMinutes, 10 * 60, reason: '${zone.anchorDate}');
      }
    });

    test('the dragged instance keeps its OWN id — it is spared from the '
        'delete-and-regenerate sweep, not swapped out from under it', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final template = await createPastDailySeries(notifier);

      final todayStart = DateTime.now();
      final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
      final todaysInstance = container
          .read(zoneListProvider)
          .firstWhere(
            (z) =>
                z.recurrenceId == template.recurrenceId &&
                z.anchorDate != null &&
                z.anchorDate!.isAtSameMomentAs(today),
          );
      final draggedId = todaysInstance.id;

      await notifier.updateZoneSeries(
        todaysInstance,
        newStartMinutes: 9 * 60,
        newEndMinutes: 10 * 60,
      );

      final stillThere = container
          .read(zoneListProvider)
          .where((z) => z.id == draggedId)
          .firstOrNull;
      expect(
        stillThere,
        isNotNull,
        reason:
            'the dragged instance\'s own id must survive the re-anchor, '
            'or any task already assigned to it would be silently '
            'orphaned',
      );
      expect(stillThere!.startMinutes, 9 * 60);
    });

    test('past instances of the series are left untouched', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final template = await createPastDailySeries(notifier);

      final beforeZones = container.read(zoneListProvider);
      // A genuinely separate, non-template past MATERIALIZED instance —
      // NOT the template itself. The template's own `startMinutes`/
      // `endMinutes` are always re-anchored regardless of its own date
      // (it represents what the series generates going forward, mirroring
      // Task's identical "the template's time-of-day always re-anchors"
      // rule) — asserting "untouched" against the template was this
      // test's own bug, caught by a real failure once this suite actually
      // ran (`Expected: <420> Actual: <540>`, i.e. the template WAS
      // re-anchored, correctly). A real past instance a few days after
      // the template's own anchor is the right thing to assert
      // "untouched" against.
      final pastInstance = beforeZones.firstWhere(
        (z) =>
            z.recurrenceId == template.recurrenceId &&
            !z.isRecurrenceTemplate &&
            z.anchorDate != null &&
            z.anchorDate!.isBefore(
              DateTime.now().subtract(const Duration(days: 25)),
            ),
      );
      final pastId = pastInstance.id;
      final pastOriginalStart = pastInstance.startMinutes;

      final todayStart = DateTime.now();
      final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
      final todaysInstance = beforeZones.firstWhere(
        (z) =>
            z.recurrenceId == template.recurrenceId &&
            z.anchorDate != null &&
            z.anchorDate!.isAtSameMomentAs(today),
      );

      await notifier.updateZoneSeries(
        todaysInstance,
        newStartMinutes: 9 * 60,
        newEndMinutes: 10 * 60,
      );

      final stillPast = container
          .read(zoneListProvider)
          .firstWhere((z) => z.id == pastId);
      expect(
        stillPast.startMinutes,
        pastOriginalStart,
        reason: 'history must not change because a future instance moved',
      );
    });
  });
}
