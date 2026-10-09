import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_inspector_panel.dart';
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

import 'fake_notification_service.dart';
import 'seeded_category_box.dart';

/// A wide window with empty content on the left and the real
/// [TaskInspectorPanel] on the right, backed by real Hive boxes — the
/// harness for the wide layout's task panel tests.
class TaskInspectorBoxes {
  late Box<Task> tasks;
  late Box<Category> categories;
  late Box<TrackedBehavior> behaviors;
  late Box<TaskTemplate> templates;

  Future<void> open(String name) async {
    Hive.init('./.dart_tool/test_hive_$name');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tasks = await Hive.openBox<Task>('test_tasks_$stamp');
    categories = await openSeededCategoryBox('test_categories_$stamp');
    behaviors = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    templates = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
  }

  Future<void> close() async {
    await tasks.close();
    await categories.close();
    await behaviors.close();
    await templates.close();
  }

  /// Pumps the host and returns its navigator, for opening tasks.
  Future<GlobalKey<NavigatorState>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(tasks)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categories),
          ),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(behaviors),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templates),
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
          home: const Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SizedBox.shrink()),
                TaskInspectorPanel(),
              ],
            ),
          ),
        ),
      ),
    );
    return navigatorKey;
  }
}

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

/// Taps [finder] and lets real Hive I/O behind the tap finish.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

DateTime daysFromToday(int days, {int hour = 9, int minute = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}
