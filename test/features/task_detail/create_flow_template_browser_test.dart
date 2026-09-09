import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
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

/// Covers the Add Task sheet's inline template browser (stage 1 / Name
/// stage only) — requested directly: "on the Add Task sheet, under Task
/// Name, let's list the templates ... Templates just as they are rendered
/// in the Template tab in Inbox, without these three dots." Narrowed to
/// templates only (no Tasks tab) via a direct follow-up.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Task name'),
  matching: find.byType(TextField),
);

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

// Hive's real disk I/O hangs under flutter_test's synchronous pump-based
// zone unless routed through WidgetTester.runAsync — see docs/ERROR_LOG.md.
// Mirrors exit_confirmation_test.dart's own established `_tapAndSettle`,
// needed here for the one test that actually completes a save (tapping
// "Schedule").
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
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

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> templateBox;

  // Real Hive disk I/O — must run inside runAsync, not a bare await in the
  // synchronous test zone (which can starve indefinitely — see
  // docs/ERROR_LOG.md). Called from inside a testWidgets body, matching
  // `template_list_view_test.dart`'s own established pattern.
  //
  // Keyed by the template's OWN `id` (a fresh UUID from `.create`), not a
  // fixed test string — matching `HiveTaskTemplateRepository.save`'s real
  // contract (`_box.put(template.id, template)`) exactly, so a test
  // asserting on `templateId` compares against the id the app itself
  // would actually look the row up by.
  Future<TaskTemplate> seedWalkTemplate(WidgetTester tester) async {
    final template = TaskTemplate.create(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.health,
      durationMinutes: 30,
      notes: 'Around the block',
    );
    await tester.runAsync(() => templateBox.put(template.id, template));
    return template;
  }

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_create_flow_template_browser');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
    await templateBox.close();
  });

  testWidgets(
    'the Name stage lists saved templates, matching the Inbox\'s own row '
    'but with no "more" (three-dot) affordance',
    (tester) async {
      await seedWalkTemplate(tester);
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      expect(find.text('Take a walk'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    },
  );

  testWidgets(
    'the template browser is gone once stage 2 (schedule fields) reveals',
    (tester) async {
      await seedWalkTemplate(tester);
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();
      expect(find.text('Take a walk'), findsOneWidget);

      await tester.enterText(_nameField(), 'Something else');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Take a walk'), findsNothing);
    },
  );

  testWidgets(
    'tapping a template row seeds THIS open form and advances to stage 2 '
    '— it does not push a second sheet',
    (tester) async {
      await seedWalkTemplate(tester);
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take a walk'));
      await tester.pumpAndSettle();

      // Advanced to stage 2 (schedule fields visible) rather than a second
      // modal route on top — exactly one Scaffold-level "Task name" field
      // exists, still showing the seeded title.
      expect(find.text('Duration'), findsOneWidget);
      final titleField = tester.widget<TextField>(_nameField());
      expect(titleField.controller!.text, 'Take a walk');
    },
  );

  testWidgets('saving a task created from a template records its templateId', (
    tester,
  ) async {
    final template = await seedWalkTemplate(tester);
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      templateBox: templateBox,
    );
    showTaskDetailSheet(
      navigatorKey.currentContext!,
      initialScheduledAt: DateTime(2026, 8, 20, 9),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take a walk'));
    await tester.pumpAndSettle();

    await _tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Schedule'),
    );

    final saved = box.values.single;
    expect(saved.title, 'Take a walk');
    expect(saved.templateId, template.id);
    expect(saved.notes, 'Around the block');
    expect(saved.durationMinutes, 30);
  });

  testWidgets(
    'the Name stage shows nothing extra when no templates are saved',
    (tester) async {
      // templateBox starts empty every test — nothing to seed here.
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      expect(find.text('Templates'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
