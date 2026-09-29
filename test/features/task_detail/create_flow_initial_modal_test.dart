import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
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

/// The real, typeable `TextField` inside the "Add title" `AppTextField` —
/// NOT `find.widgetWithText(TextField, 'Add title')`, which looks for the
/// label text as a DESCENDANT of the TextField itself. `AppFieldShell`
/// renders the floating label and the TextField as SIBLINGS, so that
/// finder never matches anything; `AppTextField`'s own subtree does
/// contain both, so descending through IT is what actually works.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Add title'),
  matching: find.byType(TextField),
);

class _ConfiguredPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  _ConfiguredPreventOverlappingTasksSetting(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Box<TrackedBehavior> trackedBehaviorBox,
  required Box<TaskTemplate> templateBox,
  bool preventOverlappingTasks = false,
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
        // The Add Task sheet's Name stage now shows an inline template
        // browser unconditionally (2026-09-07) — this box just needs to
        // exist so taskTemplateRepositoryProvider resolves; nothing here
        // exercises it, so it's never seeded.
        taskTemplateRepositoryProvider.overrideWithValue(
          HiveTaskTemplateRepository(templateBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        preventOverlappingTasksSettingProvider.overrideWith(
          () => _ConfiguredPreventOverlappingTasksSetting(
            preventOverlappingTasks,
          ),
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

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_create_flow_initial_modal');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
    // The task detail sheet's tracked-behavior link section is now
    // unconditionally compiled in (FeatureFlags.trackedBehaviorEnabled
    // defaults true as of 2026-09-06) — this box just needs to exist
    // so trackedBehaviorRepositoryProvider resolves; nothing here
    // exercises linking, so it's never seeded.
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

  testWidgets(
    'a genuinely new task opens on the Name-only first stage, with no '
    'Category/Date/Time/Duration visible yet',
    (tester) async {
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

      expect(find.text('New thing'), findsOneWidget);
      expect(_nameField(), findsOneWidget);
      expect(find.text('Label'), findsNothing);
      expect(find.text('Duration'), findsNothing);
    },
  );

  testWidgets(
    'the Inbox "give it a schedule" case (an existing, unscheduled task) '
    'skips the Name-only stage — it already has a name',
    (tester) async {
      final task = Task.captured(title: 'Already named from Inbox');
      await tester.runAsync(() => box.put(task.id, task));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        task: task,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      // Straight to the full form — the Category row (part of stage 2
      // only) is visible immediately.
      expect(find.text('Label'), findsOneWidget);
    },
  );

  testWidgets(
    'confirming the Name-only stage (Done) advances into the full form',
    (tester) async {
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

      await tester.enterText(_nameField(), 'Read a book');
      await tester.pumpAndSettle();

      final doneButton = find.text('Done');
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Stage 2's own content is now showing, and the name entered on
      // stage 1 carried through to the live preview.
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Read a book'), findsWidgets);
      expect(find.text('Schedule'), findsOneWidget);
    },
  );

  testWidgets(
    'a new task can be scheduled into an occupied time without an overlap error',
    (tester) async {
      final scheduledAt = DateTime(2026, 8, 20, 9);
      final existing = Task.create(
        title: 'Existing task',
        scheduledAt: scheduledAt,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
      );
      await tester.runAsync(() => box.put(existing.id, existing));

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
        preventOverlappingTasks: true,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: scheduledAt,
        initialTimeOfDay: const TimeOfDay(hour: 9, minute: 0),
        initialDurationMinutes: 30,
      );
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Overlapping task');
      await tester.pumpAndSettle();
      final doneButton = find.text('Done');
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
        await tester.pump();
        for (var i = 0; i < 20; i++) {
          if (box.values.length > 1) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(box.values, hasLength(2));
      final created = box.values.singleWhere(
        (task) => task.title == 'Overlapping task',
      );
      expect(created.scheduledAt, scheduledAt);
      expect(created.durationMinutes, 30);
      expect(find.textContaining('overlaps another task'), findsNothing);
      expect(find.text('New thing'), findsNothing);
    },
  );

  testWidgets(
    'tapping Done on the Name-only stage with NO name typed abandons the '
    'whole create flow',
    (tester) async {
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
      expect(find.text('New thing'), findsOneWidget);

      // Done tapped WITHOUT typing anything into the name field.
      final doneButton = find.text('Done');
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // The whole "New thing" screen is gone, and nothing was saved. No
      // confirmation dialog either: an empty title means there is
      // genuinely nothing to confirm discarding.
      expect(find.text('New thing'), findsNothing);
      expect(find.text('Discard this task?'), findsNothing);
      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'closing via the header X on the Name-only stage with no name typed '
    'closes silently too',
    (tester) async {
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

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('New thing'), findsNothing);
      expect(find.text('Discard this task?'), findsNothing);
      expect(box.values, isEmpty);
    },
  );
}
