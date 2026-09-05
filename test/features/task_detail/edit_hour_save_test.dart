import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_wheel_time_picker.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Regression test for a real bug, reported directly: "when editing task
/// and changing hour, saving, nothing happens" — the hour change was
/// silently discarded on save, not actually a no-op button. Root cause:
/// `_TaskDetailFlowState._save` assigned the bare `_scheduledAt` field
/// (which the date picker's `onDateChanged` always resets to midnight —
/// see task_detail_sheet.dart:786) instead of the already-resolved
/// `scheduledAt` local (date + `_timeOfDay` merged, the same value
/// `_canSave`'s validation already used). See task_detail_sheet.dart's own
/// fix-site comment for the full explanation.

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

// Same real-time-I/O-vs-pump-loop race documented in
// exit_confirmation_test.dart/edit_schedule_repeats_test.dart's own
// helpers — see docs/ERROR_LOG.md.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        preventOverlappingTasksSettingProvider.overrideWith(
          () => _NoopPreventOverlappingTasksSetting(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  return navigatorKey;
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_edit_hour_save');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await categoryBox.deleteFromDisk();
  });

  testWidgets(
    'changing the hour via the time wheel and saving persists the new hour, '
    'not the original one',
    (tester) async {
      final task = Task.create(
        title: 'Standup',
        scheduledAt: DateTime(2026, 9, 4, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      // Real Hive disk I/O — a bare `await` here hangs under flutter_test's
      // synchronous pump-based zone, even outside a tap. See docs/ERROR_LOG.md
      // and exit_confirmation_test.dart's own seeding calls for the same fix.
      await tester.runAsync(() => box.put(task.id, task));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showTaskDetailSheet(navigatorKey.currentContext!, task: task);
      await tester.pumpAndSettle();

      // Drive the wheel's own onChanged directly rather than a scroll
      // gesture — ListWheelScrollView drag simulation is fragile, and the
      // widget already exposes a plain callback (see
      // task_detail_sheet.dart's _ScheduleFieldsStage, which wires this
      // straight to onTimeChanged).
      final picker = tester.widget<AppWheelPicker>(find.byType(AppWheelPicker));
      picker.onChanged(14, 0); // 9:00 -> 14:00, same day.
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.text('Save'));

      final saved = box.get(task.id)!;
      expect(saved.scheduledAt, DateTime(2026, 9, 4, 14, 0));
    },
  );

  // Regression test for a real bug, reported directly: "had task that just
  // category time and it created double and both were repeated across all
  // days, saw 2 tasks everyday.. just by saving". `_save`'s own closing
  // `Navigator.pop()` was intercepted by this screen's `PopScope(canPop:
  // false)`, which routed it into `_handleClose`; that still saw the
  // never-refreshed `_initial*` snapshot differing from the edited fields,
  // so it raised the "Discard this task?" dialog AFTER a successful save —
  // and its "Save task" action ran a SECOND `_save`. See `_hasSaved` in
  // task_detail_sheet.dart.
  testWidgets(
    'saving closes the sheet outright — no post-save "Discard this task?" '
    'prompt, which could run a second save and double-write the task',
    (tester) async {
      final task = Task.create(
        title: 'Standup',
        scheduledAt: DateTime(2026, 9, 4, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showTaskDetailSheet(navigatorKey.currentContext!, task: task);
      await tester.pumpAndSettle();

      final picker = tester.widget<AppWheelPicker>(find.byType(AppWheelPicker));
      picker.onChanged(14, 0);
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.text('Save'));

      // The confirmation dialog must NOT appear after an explicit save —
      // its presence is what let a second save through.
      expect(find.text('Discard this task?'), findsNothing);
      expect(find.text('Save task'), findsNothing);
      // And the sheet is genuinely gone, not sitting behind a dialog.
      expect(find.text('Edit task'), findsNothing);

      // Exactly one row in the box: the edited task, written once.
      expect(box.values.length, 1);
      expect(box.get(task.id)!.scheduledAt, DateTime(2026, 9, 4, 14, 0));
    },
  );
}
