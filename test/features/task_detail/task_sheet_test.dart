import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
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

DateTime _daysFromToday(int days, {int hour = 9, int minute = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_sheet');
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

  Future<GlobalKey<NavigatorState>> host(WidgetTester tester) => _pumpHost(
    tester,
    box: box,
    categoryBox: categoryBox,
    trackedBehaviorBox: trackedBehaviorBox,
    templateBox: templateBox,
  );

  Task standup() => Task.create(
    title: 'Standup',
    scheduledAt: _daysFromToday(0),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.work,
  );

  testWidgets('a new task keeps its supplied start, defaults to 15 minutes, '
      'and Add writes it', (tester) async {
    final navigatorKey = await host(tester);
    showTaskSheet(
      navigatorKey.currentContext!,
      initialScheduledAt: _daysFromToday(0),
    );
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsNothing);
    expect(find.text('New thing'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).autofocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField).first, 'Walk');
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, find.text('Add'));

    final saved = box.values.single;
    expect(saved.title, 'Walk');
    expect(saved.scheduledAt, _daysFromToday(0));
    expect(saved.durationMinutes, 15);
    expect(find.text('New task'), findsNothing);
  });

  testWidgets('a new task defaults to now and enables Add after naming', (
    tester,
  ) async {
    final openedAt = DateTime.now();
    final navigatorKey = await host(tester);
    showTaskSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Walk');
    await tester.pumpAndSettle();
    final add = find.widgetWithText(ElevatedButton, 'Add');
    expect(tester.widget<ElevatedButton>(add).onPressed, isNotNull);
    await _tapAndSettle(tester, add);

    final saved = box.values.single;
    final scheduledAt = saved.scheduledAt!;
    expect(scheduledAt.difference(openedAt).inSeconds.abs(), lessThan(120));
    expect(saved.durationMinutes, 15);
  });

  testWidgets('closing an untouched sheet closes silently', (tester) async {
    final task = standup();
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await host(tester);
    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();

    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    expect(find.text('Edit task'), findsNothing);
    expect(find.text('Discard'), findsNothing);
  });

  group('closing with unsaved edits asks first', () {
    Future<void> editThenClose(WidgetTester tester, Task task) async {
      await tester.runAsync(() => box.put(task.id, task));
      final navigatorKey = await host(tester);
      showTaskSheet(navigatorKey.currentContext!, task: task);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Retro');
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
      expect(find.text('Discard'), findsOneWidget);
    }

    testWidgets('"Save as thing" saves the edit', (tester) async {
      final task = standup();
      await editThenClose(tester, task);
      await _tapAndSettle(tester, find.text('Save as thing'));
      expect(box.get(task.id)!.title, 'Retro');
      expect(find.text('Edit task'), findsNothing);
    });

    testWidgets('"Discard" closes and writes nothing', (tester) async {
      final task = standup();
      await editThenClose(tester, task);
      await _tapAndSettle(tester, find.text('Discard'));
      expect(box.get(task.id)!.title, 'Standup');
      expect(find.text('Edit task'), findsNothing);
    });

    testWidgets('"Keep editing" stays, with the edit intact', (tester) async {
      final task = standup();
      await editThenClose(tester, task);
      await _tapAndSettle(tester, find.text('Keep editing'));
      expect(find.text('Edit task'), findsNothing);
      expect(find.text('Retro'), findsOneWidget);
      expect(box.get(task.id)!.title, 'Standup');
    });

    testWidgets('the system back gesture asks the same', (tester) async {
      final task = standup();
      await tester.runAsync(() => box.put(task.id, task));
      final navigatorKey = await host(tester);
      showTaskSheet(navigatorKey.currentContext!, task: task);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Retro');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsOneWidget);
    });
  });

  testWidgets('a Things item without a time defaults its schedule before Save '
      'and lands on the Timeline', (tester) async {
    final item = Task(id: 'thing', title: 'Call mum');
    await tester.runAsync(() => box.put(item.id, item));
    final navigatorKey = await host(tester);
    showTaskSheet(navigatorKey.currentContext!, task: item);
    await tester.pumpAndSettle();

    Finder save() => find.widgetWithText(ElevatedButton, 'Save');
    expect(tester.widget<ElevatedButton>(save()).onPressed, isNotNull);
    expect(find.text('Time'), findsNothing);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('15m'), findsOneWidget);

    await _tapAndSettle(tester, save());
    final saved = box.get(item.id)!;
    expect(saved.scheduledAt, isNotNull);
    expect(saved.durationMinutes, 15);
  });

  testWidgets('a preset fills a new task and is recorded on it', (
    tester,
  ) async {
    final preset = TaskTemplate(
      id: 'preset-1',
      title: 'Meditate',
      categoryId: BuiltInCategoryIds.health,
      durationMinutes: 10,
      isImportant: true,
    );
    await tester.runAsync(() => templateBox.put(preset.id, preset));
    final navigatorKey = await host(tester);
    showTaskSheet(
      navigatorKey.currentContext!,
      initialScheduledAt: _daysFromToday(0),
    );
    await tester.pumpAndSettle();

    await _tapAndSettle(tester, find.text('Preset'));
    await _tapAndSettle(tester, find.text('Meditate'));
    expect(find.text('Meditate'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Add'));

    final saved = box.values.single;
    expect(saved.title, 'Meditate');
    expect(saved.templateId, 'preset-1');
    expect(saved.isImportant, isTrue);
  });

  testWidgets('the trash button deletes the task', (tester) async {
    final task = standup();
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await host(tester);
    // Opened from inside a page, as in the app: the undo toast anchors to
    // the opening context, which needs an Overlay above it.
    expect(navigatorKey.currentContext, isNotNull);
    showTaskSheet(tester.element(find.byType(Scaffold).first), task: task);
    await tester.pumpAndSettle();

    await _tapAndSettle(tester, find.byTooltip('Delete task'));
    expect(box.get(task.id), isNull);
  });
}
