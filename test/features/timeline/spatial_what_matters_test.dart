import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Covers a real regression, reported directly: "currently just pill
/// fades out, label stays with checkbox on task view (spatial)." The
/// Spatial (Task) view always renders `_DraggableTaskBlockState` in split
/// layout (`splitLayout: true`) — the pill (`TaskCapsuleBlock`, which
/// already carries `whatMattersFaded`) and the title/time/checkbox row
/// (`TaskCapsuleTextRow`) are two SEPARATE `Positioned` siblings in one
/// `Stack`, not ancestor/descendant, so the pill's own `AnimatedOpacity`
/// never touched the text row at all. `_buildSplit`'s own `isFaded` now
/// also checks `whatMattersEnabledSettingProvider` + `!task.isImportant`,
/// matching the pill.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_spatial_what_matters');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$suffix');
    categoryBox = await openSeededCategoryBox('test_categories_$suffix');
    zoneBox = await Hive.openBox<Zone>('test_zones_$suffix');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$suffix',
    );
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$suffix');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
  });

  Future<ProviderContainer> pumpTimeline(
    WidgetTester tester, {
    required List<Task> tasks,
  }) async {
    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
    });

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const Scaffold(
                body: TimelineScreen(mode: TimelineDisplayMode.spatial),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  // Anchored off `now`, matching this suite's siblings — see
  // multi_task_group_move_test.dart's own `makeTask` doc comment for why.
  Task makeTask(String title, {required bool isImportant}) {
    final now = DateTime.now();
    final base = (now.hour * 60 + now.minute).clamp(60, 24 * 60 - 120);
    return Task.create(
      title: title,
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(minutes: base)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
      isImportant: isImportant,
    );
  }

  testWidgets(
    'whatMattersEnabled true: BOTH the pill and the title/checkbox row '
    'fade for a non-important task — not just the pill',
    (tester) async {
      final task = makeTask('Not important', isImportant: false);
      final container = await pumpTimeline(tester, tasks: [task]);

      await tester.runAsync(
        () => container
            .read(whatMattersEnabledSettingProvider.notifier)
            .set(true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pill = tester.widget<TaskCapsuleBlock>(
        find.byWidgetPredicate(
          (w) => w is TaskCapsuleBlock && w.task.id == task.id,
        ),
      );
      expect(
        pill.whatMattersFaded,
        isTrue,
        reason: 'the pill itself must be told to fade',
      );

      final titleFinder = find.textContaining('Not important');
      expect(
        titleFinder,
        findsWidgets,
        reason: 'stays mounted through the fade, not removed outright',
      );
      // TaskCapsuleTextRow renders the title via `Text.rich` (to splice
      // in an importance marker inline) — `find.text` only matches the
      // plain-string constructor, so `textContaining` is the reliable
      // finder here.
      final ancestorOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: titleFinder, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(
        ancestorOpacity.opacity,
        0.0,
        reason:
            'the title/time/checkbox row (TaskCapsuleTextRow) must ALSO '
            'fade — it is a sibling of the pill in split layout, not a '
            'descendant, so the pill fading alone leaves this row '
            'fully visible',
      );
    },
  );

  testWidgets(
    'whatMattersEnabled true: an IMPORTANT task\'s title/checkbox row is '
    'unaffected',
    (tester) async {
      final task = makeTask('Important task', isImportant: true);
      final container = await pumpTimeline(tester, tasks: [task]);

      await tester.runAsync(
        () => container
            .read(whatMattersEnabledSettingProvider.notifier)
            .set(true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final ancestorOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.textContaining('Important task'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(ancestorOpacity.opacity, 1.0);
    },
  );
}
