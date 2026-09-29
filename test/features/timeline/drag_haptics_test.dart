import 'package:amble/core/haptics.dart';
import 'package:amble/core/haptics_provider.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
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
import 'package:amble/core/clock_provider.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/recording_haptics.dart';
import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

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
          // Pinned to midday: tasks sit near "now" so they are on screen,
          // and a late-evening run used to push them across midnight.
          nowProvider.overrideWithValue(() => _noon),
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
          home: const Scaffold(
            body: TimelineScreen(mode: TimelineDisplayMode.spatial),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Same clamped-offset-from-now shape the other Timeline test files use.
  Task makeTask(String title, {int minutes = 60}) {
    final now = _noon;
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

  testWidgets('on the Day screen a drag moves just the pill: no lifted '
      'surface, no start–end time or title carried beside it', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(pillFor('Focus block')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      final blocks = tester.widgetList<TaskCapsuleBlock>(
        pillFor('Focus block'),
      );
      expect(blocks, isNotEmpty);
      for (final block in blocks) {
        expect(block.isLifted, isFalse, reason: 'no elevated surface');
        expect(block.liftedTextInline, isFalse, reason: 'no inline time');
      }
      // The pill being moved wears the purple edit ring — but no resize
      // handles outside Edit mode.
      final moving = blocks.singleWhere((block) => !block.glyphHidden);
      expect(moving.isSelected, isTrue, reason: 'edit ring while moving');
      expect(moving.editModeEnabled, isFalse, reason: 'no resize handles');

      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a dragged pill keeps its true duration height: the resting '
      'caps (gap before the next task, zone-end margin) do not shrink it', (
    tester,
  ) async {
    final task = makeTask('Focus block');
    // Starts right as the first ends, in the same lane: at rest the first
    // pill is capped to leave a gap above this one.
    final next = Task.create(
      title: 'Next up',
      scheduledAt: task.scheduledAt!.add(
        Duration(minutes: task.durationMinutes!),
      ),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => taskBox.put(next.id, next));
    await pumpTimeline(tester, task: task);

    TaskCapsuleBlock live() => tester
        .widgetList<TaskCapsuleBlock>(pillFor('Focus block'))
        .singleWhere((block) => !block.glyphHidden);
    expect(live().maxPillHeight, isNotNull, reason: 'capped at rest');

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(pillFor('Focus block').first),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      expect(live().maxPillHeight, isNull, reason: 'uncapped mid-drag');
      expect(live().bottomTrim, 0);

      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('in Edit mode too, a drag moves just the pill', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);
    ProviderScope.containerOf(tester.element(find.byType(TimelineScreen)))
        .read(editModeEnabledProvider.notifier)
        .toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(pillFor('Focus block').first),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      for (final block in tester.widgetList<TaskCapsuleBlock>(
        pillFor('Focus block'),
      )) {
        expect(block.isLifted, isFalse);
        expect(block.liftedTextInline, isFalse);
      }
      // In Edit mode the moving pill has its ring AND its resize handles.
      final moving = tester
          .widgetList<TaskCapsuleBlock>(pillFor('Focus block'))
          .singleWhere((block) => !block.glyphHidden);
      expect(moving.isSelected, isTrue);
      expect(moving.editModeEnabled, isTrue);
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a moving task keeps the lane it started in, its ghost stays '
      'in that lane, and the tasks beside it do not shift', (tester) async {
    final first = makeTask('Lane A');
    Task overlapping(String title, int offsetMinutes) => Task.create(
      title: title,
      scheduledAt: first.scheduledAt!.add(Duration(minutes: offsetMinutes)),
      durationMinutes: first.durationMinutes!,
      categoryId: BuiltInCategoryIds.work,
    );
    final second = overlapping('Lane B', 10);
    final third = overlapping('Lane C', 20);
    await tester.runAsync(() async {
      await taskBox.put(second.id, second);
      await taskBox.put(third.id, third);
    });
    await pumpTimeline(tester, task: first);

    Finder live(String title) => find.byWidgetPredicate(
      (w) => w is TaskCapsuleBlock && w.task.title == title && !w.glyphHidden,
    );
    Finder ghost(String title) => find.byWidgetPredicate(
      (w) => w is TaskCapsuleBlock && w.task.title == title && w.glyphHidden,
    );
    final restingX = {
      for (final t in ['Lane A', 'Lane B', 'Lane C'])
        t: tester.getTopLeft(live(t)).dx,
    };

    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        tester.getCenter(live('Lane B')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getTopLeft(live('Lane B')).dx,
        restingX['Lane B'],
        reason: 'the moving task stays in its lane',
      );
      expect(
        tester.getTopLeft(ghost('Lane B')).dx,
        restingX['Lane B'],
        reason: 'its ghost stays in that lane too',
      );
      for (final t in ['Lane A', 'Lane C']) {
        expect(
          tester.getTopLeft(live(t)).dx,
          restingX[t],
          reason: '$t does not shift',
        );
      }
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
