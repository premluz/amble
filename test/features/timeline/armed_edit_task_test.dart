import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/armed_edit_task_provider.dart';
import 'package:amble/features/timeline/edit_mode_wiggle.dart';
import 'package:amble/features/timeline/resize_handle.dart';
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

/// Covers the per-task long-press arming behavior — requested directly:
/// "long press on task should enable its edit mode (duration) wiggle,
/// tapping outside closes that mode, keep single tap to open edit sheet."
///
/// Deliberately separate from the existing GLOBAL Edit Mode
/// (`editModeEnabledProvider`, covered by `edit_mode_wiggle_test.dart`
/// and others): this is per-task, triggered by a long-press with no
/// toolbar toggle involved, and every test here runs with the global
/// toggle OFF to prove the new behavior is fully independent of it — see
/// `armed_edit_task_provider.dart`'s own doc comment for the full
/// reasoning. Uses the same full-`TimelineScreen`-pump shape
/// `multi_task_selection_test.dart` already established.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_armed_edit_task');
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

  Future<void> pumpTimeline(
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
    // NOT pumpAndSettle — EditModeWiggle starts a perpetually-repeating
    // AnimationController once a task is armed, same reason
    // `multi_task_selection_test.dart`'s own pumpTimeline avoids it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Anchored around `now` (like `tap_empty_space_quick_create_test.dart`'s
  // own tap position, which always lands near `now` because the Timeline
  // scrolls to centre on it) rather than a fixed clock hour — a fixed hour
  // only stays on-screen by coincidence of when the suite happens to run.
  // See docs/ERROR_LOG.md's "tap_empty_space_quick_create_test.dart's
  // overlap-refusal test failed only after ~19:00" entry for the same bug
  // in a different file.
  //
  // The Timeline itself always opens on TODAY's calendar day, so simply
  // adding a `Duration` to `now` isn't safe on its own — near either edge
  // of the day it can carry the date over onto TOMORROW (or YESTERDAY),
  // and the task silently never appears in today's view at all (this bit
  // an earlier version of this same helper: confirmed empirically at
  // 23:48, where `now + 40 minutes` rolled to 00:28 the next calendar
  // day). Clamping the minutes-since-midnight to stay within [0, 1439]
  // keeps the offset task on the SAME day as `now` no matter what time
  // the suite runs, at the cost of the offset shrinking near midnight —
  // acceptable here since these tests only need two tasks distinguishably
  // apart, not a specific gap.
  Task makeTask(String title, {int minuteOffset = 0, int minutes = 30}) {
    final now = DateTime.now();
    final minutesSinceMidnight = (now.hour * 60 + now.minute + minuteOffset)
        .clamp(0, 24 * 60 - 1);
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

  testWidgets('long-pressing a task arms it — resize handles appear, with the '
      'global Edit Mode toggle OFF the whole time', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, tasks: [task]);

    expect(find.byType(ResizeHandle), findsNothing);

    await tester.longPress(find.text('Focus block'));
    await tester.pump();

    expect(find.byType(ResizeHandle), findsWidgets);
  });

  testWidgets(
    'long-pressing a task arms ONLY that task — a second, un-pressed task '
    'shows no resize handle',
    (tester) async {
      final a = makeTask('Focus block', minuteOffset: -40);
      final b = makeTask('Standup', minuteOffset: 40);
      await pumpTimeline(tester, tasks: [a, b]);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      // One armed task contributes its own top+bottom handle pair; a
      // second, unarmed task contributes none.
      expect(find.byType(ResizeHandle), findsNWidgets(2));
    },
  );

  testWidgets(
    'tapping empty timeline space closes an armed task\'s edit state',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, tasks: [task]);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();
      expect(find.byType(ResizeHandle), findsWidgets);
      expect(capturedContainer!.read(armedEditTaskProvider), task.id);

      // A point on the timeline background, well clear of the 9:00 task's
      // own pill — matches the empty-space-tap harness other timeline
      // tests already use for the same kind of background tap.
      await tester.tapAt(const Offset(220, 700));
      await tester.pump();

      expect(capturedContainer!.read(armedEditTaskProvider), isNull);
    },
  );

  testWidgets('tapping a DIFFERENT task while one is armed opens that task\'s '
      'detail sheet AND clears the arming', (tester) async {
    final a = makeTask('Focus block', minuteOffset: -40);
    final b = makeTask('Standup', minuteOffset: 40);
    await pumpTimeline(tester, tasks: [a, b]);

    await tester.longPress(find.text('Focus block'));
    await tester.pump();
    expect(capturedContainer!.read(armedEditTaskProvider), a.id);

    await tester.tap(find.text('Standup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Edit task'), findsOneWidget);
    expect(capturedContainer!.read(armedEditTaskProvider), isNull);
  });

  testWidgets(
    'a single tap on the armed task itself still opens the detail sheet '
    '— long-press arming never replaces the ordinary tap contract',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, tasks: [task]);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.tap(find.text('Focus block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit task'), findsOneWidget);
    },
  );

  testWidgets(
    'an armed task wiggles even though the global Edit Mode toggle is off',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, tasks: [task]);

      final wiggleBefore = tester.widget<EditModeWiggle>(
        find.byType(EditModeWiggle).first,
      );
      expect(wiggleBefore.enabled, isFalse);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      final wiggleAfter = tester.widget<EditModeWiggle>(
        find.byType(EditModeWiggle).first,
      );
      expect(wiggleAfter.enabled, isTrue);
    },
  );
}
