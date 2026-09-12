import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/armed_edit_task_provider.dart';
import 'package:amble/features/timeline/task_edge_time_label.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// A wiggling/selected task in Edit Mode shows its own start/end via the
/// same accent "time on the right" treatment the long-press placement
/// line and the pending draft pill use — requested directly: "also in
/// edit mode for selected (wiggly tasks) we need to show it." Mirrors
/// `armed_edit_task_test.dart`'s own full-`TimelineScreen` pump shape.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_edit_time_labels');
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
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$suffix');
    capturedContainer = null;
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await templateBox.close();
  });

  Future<void> pumpTimeline(WidgetTester tester, {required Task task}) async {
    await tester.runAsync(() => taskBox.put(task.id, task));

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
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedContainer = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const Scaffold(body: TimelineScreen()),
            );
          },
        ),
      ),
    );
    // NOT pumpAndSettle — EditModeWiggle's perpetually-repeating animation
    // never settles once a task is armed, same fix every wiggle-adjacent
    // test in this suite already applies.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Same clamped-offset-from-now shape `armed_edit_task_test.dart` uses,
  // for the same reason: a fixed clock hour only stays on-screen by
  // coincidence of when the suite happens to run.
  Task makeTask(String title, {int minutes = 60}) {
    final now = DateTime.now();
    final minutesSinceMidnight = (now.hour * 60 + now.minute).clamp(
      0,
      24 * 60 - 1 - minutes,
    );
    return Task.create(
      title: title,
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(minutes: minutesSinceMidnight)),
      durationMinutes: minutes,
      categoryId: BuiltInCategoryIds.work,
    );
  }

  testWidgets('an ordinary (unarmed) task shows no start/end edge labels', (
    tester,
  ) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);

    expect(find.byType(TaskEdgeTimeLabel), findsNothing);
  });

  testWidgets(
    'long-pressing a task to arm it reveals its own start/end edge labels',
    (tester) async {
      final task = makeTask('Focus block', minutes: 90);
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));

      final labels = tester
          .widgetList<TaskEdgeTimeLabel>(find.byType(TaskEdgeTimeLabel))
          .toList();
      final expectedStart = TimeOfDay.fromDateTime(task.scheduledAt!);
      final expectedEnd = TimeOfDay.fromDateTime(
        task.scheduledAt!.add(Duration(minutes: task.durationMinutes!)),
      );
      expect(
        labels.map((l) => l.time),
        containsAll([expectedStart, expectedEnd]),
      );

      // Both labels sit over the hour gutter on the LEFT, not at the
      // pill's own top/bottom-right — reported directly: "when wiggling
      // on left generally all cases on left side." A gutter-pinned label
      // renders at a far smaller x than the pill itself (which sits well
      // into the day column); this simply confirms it did NOT stay at
      // the pill's own x, without hard-coding the exact gutter pixel
      // width.
      // Measure the rendered TEXT inside each label, not the outer
      // Positioned wrapper — a Positioned(left: 0, right: 0) box reports
      // the same top-left regardless of whether its content aligns left
      // or right inside it, so only the actual painted text position can
      // distinguish "pinned to the gutter" from "right-aligned within
      // the row" (the previous, incorrect layout).
      final pillX = tester.getTopLeft(find.text('Focus block')).dx;
      for (final labelFinder in [
        find.byType(TaskEdgeTimeLabel).first,
        find.byType(TaskEdgeTimeLabel).last,
      ]) {
        final textFinder = find.descendant(
          of: labelFinder,
          matching: find.byType(Text),
        );
        final labelTextX = tester.getTopLeft(textFinder).dx;
        expect(
          labelTextX,
          lessThan(pillX),
          reason:
              'edge label text should sit left of the pill, over the '
              'gutter, not right-aligned within the row',
        );
      }
    },
  );

  testWidgets(
    'closing the armed task\'s edit state hides the edge labels again',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();
      expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));

      // Tapping the armed task itself closes its edit state (opens the
      // detail sheet instead) — same close path
      // `armed_edit_task_test.dart`'s own "single tap on the armed task"
      // test uses. NOT an empty-space tap: this Timeline's own
      // tap-to-quick-create feature (`onEmptyTap`) fires on ANY empty
      // background tap and would create a brand new pending draft there
      // — which now shows its OWN pair of edge labels (this same
      // session's other feature), confounding this test's count.
      await tester.tap(find.text('Focus block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        capturedContainer!.read(armedEditTaskProvider),
        isNull,
        reason:
            'the tap should have cleared the armed task first — if '
            'this fails, the test\'s own tap position/harness is wrong, '
            'not the edge-label feature',
      );
      expect(find.text('Edit task'), findsOneWidget);

      expect(find.byType(TaskEdgeTimeLabel), findsNothing);
    },
  );
}
