import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_action_sheet.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
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

DateTime _daysFromToday(int days, {int hour = 9}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<void> _pumpActionSheet(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Task task,
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
  showTaskActionSheet(navigatorKey.currentContext!, task: task);
  await tester.pumpAndSettle();
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_action_sheet_remove');
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
    await box.close();
    await categoryBox.close();
  });

  testWidgets('Remove on a PLAIN task deletes it', (tester) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Remove'));

    expect(box.get(task.id), isNull, reason: 'plain task should be deleted');
  });

  testWidgets('Remove on a RECURRING task opens the scope sheet', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [DateTime.monday],
      ),
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Remove'));

    expect(
      find.text('This task repeats'),
      findsOneWidget,
      reason: 'scope sheet should appear for a recurring task',
    );
  });

  testWidgets('"Remove this occurrence" deletes only the tapped instance', (
    tester,
  ) async {
    final template = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [DateTime.monday],
      ),
    );
    final sibling = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(7),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
    );
    await tester.runAsync(() async {
      await box.put(template.id, template);
      await box.put(sibling.id, sibling);
    });

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: template,
    );
    await _tapAndSettle(tester, find.text('Remove'));
    await _tapAndSettle(tester, find.text('Remove this occurrence'));

    expect(box.get(template.id), isNull);
    expect(
      box.get(sibling.id),
      isNotNull,
      reason: 'the rest of the series must survive',
    );
  });

  testWidgets('"Remove all occurrences" deletes this and future instances', (
    tester,
  ) async {
    final template = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [DateTime.monday],
      ),
    );
    final future = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(7),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
    );
    final past = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(-7),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
    );
    await tester.runAsync(() async {
      await box.put(template.id, template);
      await box.put(future.id, future);
      await box.put(past.id, past);
    });

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: template,
    );
    await _tapAndSettle(tester, find.text('Remove'));
    await _tapAndSettle(tester, find.text('Remove all occurrences'));

    expect(box.get(template.id), isNull);
    expect(box.get(future.id), isNull, reason: 'future instances go');
    expect(
      box.get(past.id),
      isNotNull,
      reason: 'past instances are kept as history',
    );
  });

  testWidgets(
    'Duplicate opens a pre-filled create screen WITHOUT persisting a copy '
    'until Save is actually tapped',
    (tester) async {
      // Fixed directly: Duplicate used to call TaskList.duplicateTask
      // immediately on tap — a real repository write — so closing the
      // follow-up screen without confirming still left an unwanted
      // duplicate behind. It now opens the same create/edit screen
      // pre-filled from the source task, and nothing is written until the
      // user actually saves. See docs/PROGRESS_LOG.md.
      final task = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpActionSheet(
        tester,
        box: box,
        categoryBox: categoryBox,
        task: task,
      );
      await _tapAndSettle(tester, find.text('Duplicate'));

      // Pre-filled with the source task's title, on the full (stage 2)
      // form directly — a duplicate already has a name, so it skips the
      // Name-only first stage.
      expect(find.text('Standup'), findsWidgets);
      expect(find.text('Schedule'), findsOneWidget);
      // Still exactly ONE task — nothing persisted merely by opening
      // the screen.
      expect(box.values.length, 1);
    },
  );

  testWidgets('Edit task opens the edit screen, pre-filled', (tester) async {
    // "Edit details" was consolidated into a single "Edit task" entry —
    // see docs/PROGRESS_LOG.md — that opens the same screen Create uses,
    // pre-populated, with every field editable in one place.
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Edit task'));

    expect(find.text('Standup'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
  });
}
