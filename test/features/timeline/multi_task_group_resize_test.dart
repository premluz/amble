import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/resize_handle.dart';
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

/// Covers Edit Mode's multi-task group RESIZE — requested directly:
/// "resizing, all would resize, all selected" — the SAME duration delta
/// applied to every selected task, each floored independently at its own
/// minimum (confirmed via AskUserQuestion), never a normalized shared
/// duration. See `group_reschedule_test.dart`/`multi_task_group_move_test
/// .dart` for the move-axis equivalent this file mirrors, and
/// `task_providers_test.dart`'s `resizeTasksInBatch` group for the
/// underlying batch-write coverage this file doesn't repeat.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_multi_task_group_resize');
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
    capturedContainer = null;
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
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
          editModeEnabledProvider.overrideWith(
            () => _FixedEditModeEnabled(true),
          ),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedDevMultiTaskEditMode(true),
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
    // NOT pumpAndSettle — EditModeWiggle's perpetual animation never
    // settles. See multi_task_selection_test.dart's own pumpTimeline for
    // the full explanation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Task makeTask(String title, {int hour = 9, int minutes = 30}) {
    final now = DateTime.now();
    return Task.create(
      title: title,
      scheduledAt: DateTime(now.year, now.month, now.day, hour),
      durationMinutes: minutes,
      categoryId: BuiltInCategoryIds.work,
    );
  }

  Finder pillFor(String title) => find.byWidgetPredicate(
    (widget) => widget is TaskCapsuleBlock && widget.task.title == title,
  );

  // `.last` is the BOTTOM handle: TaskCapsuleBlock renders the top-edge
  // handle first in its Stack, the bottom one second. Group resize is a
  // bottom-edge behaviour (the top edge is single-task only, by decision
  // — see CONSTITUTION.md), so these tests must target the bottom one
  // specifically. Before the top handle existed this finder matched a
  // single widget; once it matched two, `tester.drag` threw on the
  // ambiguity and no resize ran at all, which surfaced as durations
  // simply never changing.
  Finder handleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .last;

  /// `.first` is the TOP handle — TaskCapsuleBlock renders top-first.
  Finder topHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .first;

  testWidgets(
    'dragging one selected task\'s handle resizes every OTHER selected '
    'task by the same delta, each keeping its own scheduledAt — an '
    'unselected task is left untouched',
    (tester) async {
      final a = makeTask('Focus block', hour: 9, minutes: 30);
      final b = makeTask('Standup', hour: 13, minutes: 60);
      final untouched = makeTask('Lunch', hour: 12, minutes: 45);
      // Captured before the drag — Hive's in-memory Box returns the SAME
      // Task object on every `get`, so `a`/`b` themselves get mutated in
      // place by the very write this test is checking. See
      // multi_task_group_move_test.dart's own comment on this.
      final originalScheduledAtA = a.scheduledAt;
      final originalScheduledAtB = b.scheduledAt;
      await pumpTimeline(tester, tasks: [a, b, untouched]);

      await tester.tap(find.text('Focus block'));
      await tester.pump();
      await tester.tap(find.text('Standup'));
      await tester.pump();
      expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});

      // Drag the handle down — grows both selected tasks' durations by
      // the same amount, well past the 5-minute snap threshold.
      await tester.runAsync(() async {
        await tester.drag(handleFor('Focus block'), const Offset(0, 90));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 400));

      final savedA = taskBox.get(a.id)!;
      final savedB = taskBox.get(b.id)!;
      final savedUntouched = taskBox.get(untouched.id)!;

      expect(savedA.durationMinutes, isNot(30));
      expect(savedB.durationMinutes, isNot(60));
      expect(savedUntouched.durationMinutes, 45);

      // The whole point of a group resize: the SAME delta, not a shared
      // normalized duration — a and b started 30 apart and must stay 30
      // apart.
      expect(savedB.durationMinutes! - savedA.durationMinutes!, 30);

      // scheduledAt is never touched by a resize, group or not — per
      // CONSTITUTION.md.
      expect(savedA.scheduledAt, originalScheduledAtA);
      expect(savedB.scheduledAt, originalScheduledAtB);
    },
  );

  testWidgets('a selected task already at the resize floor stays there, while '
      'another selected task with room still shrinks by the same delta', (
    tester,
  ) async {
    // a is already at the resize floor (5 min); b has plenty of room.
    final a = makeTask('Focus block', hour: 9, minutes: 5);
    final b = makeTask('Standup', hour: 13, minutes: 60);
    await pumpTimeline(tester, tasks: [a, b]);

    await tester.tap(find.text('Focus block'));
    await tester.pump();
    await tester.tap(find.text('Standup'));
    await tester.pump();

    // Drag the handle UP (shrink) by a large amount.
    await tester.runAsync(() async {
      await tester.drag(handleFor('Focus block'), const Offset(0, -300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));

    final savedA = taskBox.get(a.id)!;
    final savedB = taskBox.get(b.id)!;

    // a was already AT the floor — a large shrink still can't push it
    // any lower.
    expect(savedA.durationMinutes, 5);
    // b, with plenty of room, still shrinks by the SAME raw delta
    // requested (confirmed via AskUserQuestion: same delta to each,
    // never a shared/renormalized clamp) — a hitting its own floor
    // doesn't cap what b does. b just never goes below its OWN floor
    // either.
    expect(savedB.durationMinutes, greaterThanOrEqualTo(5));
    expect(savedB.durationMinutes, lessThan(60));
  });

  // Reported directly as a bug: "top resize in multi select not resizing
  // all selected like bottom does." The top edge originally broadcast
  // nothing under multi-task mode — a rule that was itself confirmed at
  // the time and is now reversed (see CONSTITUTION.md).
  group('group TOP-edge resize (2026-09-08)', () {
    testWidgets(
      'dragging one selected task\'s TOP handle moves every OTHER selected '
      'task\'s start by the same delta and compensates its duration, so '
      'each keeps its own END anchored — an unselected task is untouched',
      (tester) async {
        final a = makeTask('Focus block', hour: 9, minutes: 60);
        final b = makeTask('Standup', hour: 13, minutes: 90);
        final untouched = makeTask('Lunch', hour: 12, minutes: 45);
        final originalStartA = a.scheduledAt!;
        final originalStartB = b.scheduledAt!;
        final originalEndA = originalStartA.add(const Duration(minutes: 60));
        final originalEndB = originalStartB.add(const Duration(minutes: 90));
        await pumpTimeline(tester, tasks: [a, b, untouched]);

        await tester.tap(find.text('Focus block'));
        await tester.pump();
        await tester.tap(find.text('Standup'));
        await tester.pump();
        expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});

        // Drag the TOP handle down — pulls each start later, shrinking
        // each task from the top while its end stays put.
        await tester.runAsync(() async {
          await tester.drag(topHandleFor('Focus block'), const Offset(0, 30));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 400));

        final savedA = taskBox.get(a.id)!;
        final savedB = taskBox.get(b.id)!;
        final savedUntouched = taskBox.get(untouched.id)!;

        // BOTH selected tasks moved — this is the actual bug report.
        expect(
          savedA.scheduledAt,
          isNot(originalStartA),
          reason: 'the dragged task must move',
        );
        expect(
          savedB.scheduledAt,
          isNot(originalStartB),
          reason: 'the OTHER selected task must move too — the bug',
        );

        // The same delta, applied to each.
        expect(
          savedB.scheduledAt!.difference(originalStartB),
          savedA.scheduledAt!.difference(originalStartA),
        );

        // Each END stays anchored, which is what distinguishes the top
        // edge from a group move.
        expect(
          savedA.scheduledAt!.add(Duration(minutes: savedA.durationMinutes!)),
          originalEndA,
        );
        expect(
          savedB.scheduledAt!.add(Duration(minutes: savedB.durationMinutes!)),
          originalEndB,
        );

        expect(savedUntouched.durationMinutes, 45);
      },
    );

    testWidgets('a selected task already at the duration floor stays put while '
        'another selected task with room still moves — each clamped on its '
        'own, never inverted', (tester) async {
      final roomy = makeTask('Focus block', hour: 9, minutes: 120);
      final tiny = makeTask('Standup', hour: 13, minutes: 5);
      final originalTinyStart = tiny.scheduledAt!;
      final originalRoomyStart = roomy.scheduledAt!;
      await pumpTimeline(tester, tasks: [roomy, tiny]);

      await tester.tap(find.text('Focus block'));
      await tester.pump();
      await tester.tap(find.text('Standup'));
      await tester.pump();

      // A large downward drag: plenty of room on one, none on the other.
      await tester.runAsync(() async {
        await tester.drag(topHandleFor('Focus block'), const Offset(0, 120));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 400));

      final savedRoomy = taskBox.get(roomy.id)!;
      final savedTiny = taskBox.get(tiny.id)!;

      expect(savedRoomy.scheduledAt, isNot(originalRoomyStart));
      // Already at the floor — it must not move, and above all must
      // never end up with a zero or negative duration.
      expect(savedTiny.scheduledAt, originalTinyStart);
      expect(savedTiny.durationMinutes, 5);
      expect(savedRoomy.durationMinutes, greaterThan(0));
    });
  });
}

class _FixedEditModeEnabled extends EditModeEnabled {
  _FixedEditModeEnabled(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;
}

class _FixedDevMultiTaskEditMode extends DevMultiTaskEditMode {
  _FixedDevMultiTaskEditMode(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;
}
