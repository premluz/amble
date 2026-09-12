import 'package:amble/core/haptics.dart';
import 'package:amble/core/haptics_provider.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/hive_registrar.g.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/recording_haptics.dart';
import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Timeline gesture haptics. Unlike the leaf widgets in
/// `test/core/haptics_test.dart` (which take an injected `Haptics`), these
/// blocks are `ConsumerState`s that read `hapticsProvider`, so the fake
/// goes in as a `ProviderScope` override.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;
  late RecordingHaptics haptics;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_drag_haptics');
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
    haptics = RecordingHaptics();
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
          hapticsProvider.overrideWithValue(haptics),
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
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TimelineScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Same clamped-offset-from-now shape the other Timeline test files use.
  Task makeTask(String title, {int minutes = 60}) {
    final now = DateTime.now();
    final minutesSinceMidnight = (now.hour * 60 + now.minute).clamp(
      60,
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

  Finder pillFor(String title) => find.byWidgetPredicate(
    (widget) => widget is TaskCapsuleBlock && widget.task.title == title,
  );

  testWidgets('a move-drag lifts, ticks per snap increment, and drops', (
    tester,
  ) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(pillFor('Focus block')),
      );
      // Several small moves rather than one jump, same as the other drag
      // tests: the gesture arena has to resolve the recognizer before
      // onDragUpdate's delta accumulates at all.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }

      expect(
        haptics.played.first,
        AmbleHaptic.lift,
        reason: 'picking the block up should be the first thing felt',
      );
      // The drag crossed real distance, so at least one 5-minute snap
      // increment must have ticked.
      expect(haptics.played, contains(AmbleHaptic.selection));

      await gesture.up();
      // A real delay inside runAsync, not pumpAndSettle — the release
      // kicks off a genuine repository write, and this is the same way
      // every other drag test in this directory lets that land before
      // teardown closes the boxes out from under it.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        haptics.played.last,
        AmbleHaptic.drop,
        reason: 'releasing should be the last thing felt',
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the snap tick fires once per crossed increment, not per frame', (
    tester,
  ) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(pillFor('Focus block')),
      );
      // Resolve the recognizer first, then hold perfectly still for many
      // frames. A per-frame implementation would pile up ticks here; an
      // edge-triggered one adds none.
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final afterFirstMove = haptics.played.length;

      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset.zero);
        await tester.pump();
      }

      expect(haptics.played.length, afterFirstMove);

      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
