import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/overlap_cluster_block.dart';
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
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// List (collapsed) mode should follow the same overlap-clustering
/// behavior Task view already has — requested directly, since List mode
/// previously only ever used `layoutOverlappingTasks`' plain side-by-side
/// column split, never collapsing 2-3 overlapping tasks into the shared
/// `OverlapClusterBlock` treatment.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_list_clustering');
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

  Future<void> pumpTimelineInListMode(WidgetTester tester) async {
    // Seed a genuine 2-task overlap on "today" (tasksForSelectedDayProvider
    // defaults to today) — the same shape overlap_cluster_main.dart's own
    // dev-scaffold uses to verify Task view's clustering.
    final now = DateTime.now();
    DateTime at(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    final overlapping = [
      Task.create(
        title: 'Deep work',
        scheduledAt: at(9, 0),
        durationMinutes: 90,
        categoryId: BuiltInCategoryIds.work,
      ),
      Task.create(
        title: 'Standup',
        scheduledAt: at(9, 30),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.admin,
      ),
    ];
    for (final task in overlapping) {
      await taskBox.put(task.id, task);
    }

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
          // List mode: hour labels off, Zone view off — see day_strip.dart's
          // own TimelineViewMode mapping.
          showHourLabelsSettingProvider.overrideWith(
            () => _FixedShowHourLabels(false),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TimelineScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a 2-task overlap in List mode collapses into OverlapClusterBlock, '
    'the same as Task view',
    (tester) async {
      await pumpTimelineInListMode(tester);

      expect(find.byType(OverlapClusterBlock), findsOneWidget);
    },
  );

  testWidgets('List mode still respects the "disable clustering" setting — no '
      'OverlapClusterBlock when it\'s on', (tester) async {
    await preferencesBox.put(PreferenceKeys.disableOverlapClustering, true);
    await pumpTimelineInListMode(tester);

    expect(find.byType(OverlapClusterBlock), findsNothing);
  });
}

class _FixedShowHourLabels extends ShowHourLabelsSetting {
  _FixedShowHourLabels(this._value);

  final bool _value;

  @override
  bool build() => _value;
}
