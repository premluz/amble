import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_switch.dart';
import 'package:amble/core/widgets/app_wheel_time_picker.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
import 'package:amble/features/task_detail/task_sheet_fields.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/providers/occurrence_store.dart';
import 'package:amble/shared/repositories/occurrence_record_repository.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Covers the recurring-edit scope choice requested directly: moving a
/// recurring task's start time or duration now shows "Affect future
/// instances" (off by default — "just this occurrence") instead of the
/// old silent always-cascade-to-future behavior. See
/// docs/CONSTITUTION.md's reversal of the original "editing a materialized
/// instance only ever affects that single instance" MVP scope, and
/// task_providers_test.dart's `updateTaskThisInstanceOnly` unit coverage
/// for the underlying provider-level mechanics this toggle drives.

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

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
  required Box<TrackedBehavior> trackedBehaviorBox,
  required Box<TaskTemplate> templateBox,
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
        trackedBehaviorRepositoryProvider.overrideWithValue(
          HiveTrackedBehaviorRepository(trackedBehaviorBox),
        ),
        taskTemplateRepositoryProvider.overrideWithValue(
          HiveTaskTemplateRepository(templateBox),
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

/// Moves the open task sheet's start to [hour]:00 — the time chip (Date,
/// Time, Duration: the second) opens the Start time picker; Done applies.
Future<void> _setStartHour(WidgetTester tester, int hour) async {
  await _tapAndSettle(
    tester,
    find
        .descendant(
          of: find.byType(TaskSheetFields),
          matching: find.byType(AppValueChip),
        )
        .at(1),
  );
  tester.widget<AppWheelPicker>(find.byType(AppWheelPicker)).onChanged(hour, 0);
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.text('Done'));
}

DateTime _daysFromToday(int days, {int hour = 9, int minute = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

/// A daily "Standup" series at 9:00 from today, through the real
/// `createTask`.
Future<void> _seedDailySeries(
  WidgetTester tester,
  GlobalKey<NavigatorState> key,
) async {
  final container = ProviderScope.containerOf(key.currentContext!);
  await tester.runAsync(
    () => container
        .read(taskListProvider.notifier)
        .createTask(
          title: 'Standup',
          scheduledAt: _daysFromToday(0),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
          recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        ),
  );
}

Task _occurrenceOn(GlobalKey<NavigatorState> key, DateTime day) =>
    ProviderScope.containerOf(key.currentContext!)
        .read(occurrenceStoreProvider.notifier)
        .tasksOn(LocalDate.fromDateTime(day))
        .single;

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_affect_future_instances');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_${DateTime.now().microsecondsSinceEpoch}',
    );
    templateBox = await Hive.openBox<TaskTemplate>(
      'test_templates_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
    await templateBox.close();
  });

  testWidgets('editing a NON-recurring task never shows the toggle, even after '
      'changing the hour', (tester) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      templateBox: templateBox,
    );
    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();

    expect(find.text('Affect future instances'), findsNothing);

    await _setStartHour(tester, 14);

    expect(find.text('Affect future instances'), findsNothing);
  });

  testWidgets(
    'editing a recurring task WITHOUT touching time/duration never shows '
    'the toggle',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      await tester.runAsync(() => box.put(template.id, template));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskSheet(navigatorKey.currentContext!, task: template);
      await tester.pumpAndSettle();

      expect(find.text('Affect future instances'), findsNothing);
    },
  );

  testWidgets(
    'changing the hour on a recurring task reveals the toggle, defaulting '
    'off ("just this occurrence")',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      await tester.runAsync(() => box.put(template.id, template));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskSheet(navigatorKey.currentContext!, task: template);
      await tester.pumpAndSettle();

      await _setStartHour(tester, 14);

      expect(find.text('Affect future instances'), findsOneWidget);
      final switchWidget = tester.widget<AppSwitch>(
        find.byType(AppSwitch).last,
      );
      expect(switchWidget.value, isFalse);
    },
  );

  testWidgets(
    'leaving the toggle off and saving a moved occurrence moves only that '
    'occurrence — the series and every other day are unchanged',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _seedDailySeries(tester, navigatorKey);
      showTaskSheet(
        navigatorKey.currentContext!,
        task: _occurrenceOn(navigatorKey, _daysFromToday(0)),
      );
      await tester.pumpAndSettle();

      await _setStartHour(tester, 14);
      // Toggle left off (default) — "just this occurrence".
      await _tapAndSettle(tester, find.text('Save'));

      expect(
        _occurrenceOn(navigatorKey, _daysFromToday(0)).scheduledAt,
        _daysFromToday(0, hour: 14),
      );
      expect(
        _occurrenceOn(navigatorKey, _daysFromToday(1)).scheduledAt,
        _daysFromToday(1),
      );
      expect(HiveSeriesRepository.opened().getAll().single.version, 1);
    },
  );

  testWidgets(
    'turning the toggle on and saving a moved occurrence moves it and every '
    'later day — a new revision from this date',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _seedDailySeries(tester, navigatorKey);
      showTaskSheet(
        navigatorKey.currentContext!,
        task: _occurrenceOn(navigatorKey, _daysFromToday(0)),
      );
      await tester.pumpAndSettle();

      await _setStartHour(tester, 14);
      await _tapAndSettle(tester, find.byType(AppSwitch).last);
      await _tapAndSettle(tester, find.text('Save'));

      for (final day in [0, 1, 7]) {
        expect(
          _occurrenceOn(navigatorKey, _daysFromToday(day)).scheduledAt,
          _daysFromToday(day, hour: 14),
        );
      }
      // Changed by the series, not by per-day overrides.
      expect(HiveOccurrenceRecordRepository.opened().getAll(), isEmpty);
    },
  );
}
