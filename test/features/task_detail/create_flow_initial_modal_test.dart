import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/features/task_detail/task_name_category_modal.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
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

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_create_flow_initial_modal');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets(
    'a genuinely new task opens the Name/Category modal automatically, '
    'without the pencil being tapped',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      // A single pumpAndSettle: the auto-open runs off a post-frame
      // callback scheduled during the SAME build that pushes this
      // screen's own route, so it fires within this settle rather than
      // needing a separate pump.
      await tester.pumpAndSettle();

      expect(find.byType(TaskNameCategoryModal), findsOneWidget);
    },
  );

  testWidgets(
    'the Inbox "give it a schedule" case (an existing, unscheduled task) '
    'does NOT auto-open the modal — it already has a name',
    (tester) async {
      final task = Task.captured(title: 'Already named from Inbox');
      await tester.runAsync(() => box.put(task.id, task));

      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        task: task,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskNameCategoryModal), findsNothing);
    },
  );

  testWidgets(
    'confirming the auto-opened modal continues the guided sequence into '
    'Start time, matching a manually-tapped pencil',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      final nameField = find
          .descendant(
            of: find.byType(TaskNameCategoryModal),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(nameField, 'Read a book');
      await tester.pumpAndSettle();

      final doneButton = find.descendant(
        of: find.byType(TaskNameCategoryModal),
        matching: find.text('Done'),
      );
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Auto-advanced into Start time, per the existing guided sequence —
      // this is unchanged behaviour, just now reachable without a tap on
      // the pencil to get the first modal open.
      expect(find.text('Start time'), findsOneWidget);
    },
  );

  testWidgets(
    'dismissing the auto-opened modal without a name leaves the main '
    'screen usable, with Confirm still disabled',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      // Dismiss via the scrim, above the sheet, without typing a name.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      expect(find.byType(TaskNameCategoryModal), findsNothing);
      expect(find.text('Create task'), findsOneWidget);
      final confirmButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Schedule'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(confirmButton.onPressed, isNull);
    },
  );

  testWidgets(
    'tapping Done on the auto-opened modal with NO name typed abandons '
    'the whole create flow — both the modal and the main screen close',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskNameCategoryModal), findsOneWidget);

      // Done tapped WITHOUT typing anything into the name field.
      final doneButton = find.descendant(
        of: find.byType(TaskNameCategoryModal),
        matching: find.text('Done'),
      );
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Not just the modal — the main "Create task" screen is gone too,
      // and nothing was saved. No confirmation dialog either: an empty
      // title means there is genuinely nothing to confirm discarding.
      expect(find.byType(TaskNameCategoryModal), findsNothing);
      expect(find.text('Create task'), findsNothing);
      expect(find.text('Discard this task?'), findsNothing);
      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'reopening the pencil LATER (after time/duration are already set) and '
    'tapping Done with an empty name does NOT abandon the flow — only the '
    'very first auto-opened modal can do that',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      // Complete the guided sequence with a real name, so
      // _autoAdvanceEligible turns itself off — matching a user who has
      // already made real progress on the task.
      final nameField = find
          .descendant(
            of: find.byType(TaskNameCategoryModal),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(nameField, 'Read a book');
      await tester.pumpAndSettle();
      var doneButton = find.descendant(
        of: find.byType(TaskNameCategoryModal),
        matching: find.text('Done'),
      );
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Auto-advanced into Start time — back out via the scrim to stop
      // the guided sequence here, leaving _autoAdvanceEligible false.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text('Create task'), findsOneWidget);

      // Now re-open the pencil and clear the name back to empty.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final reopenedNameField = find
          .descendant(
            of: find.byType(TaskNameCategoryModal),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(reopenedNameField, '');
      await tester.pumpAndSettle();
      doneButton = find.descendant(
        of: find.byType(TaskNameCategoryModal),
        matching: find.text('Done'),
      );
      await tester.ensureVisible(doneButton);
      await tester.pumpAndSettle();
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // The main screen is still there — this was NOT the first
      // auto-opened modal, so an empty name here just closes that one
      // modal rather than abandoning the whole flow.
      expect(find.byType(TaskNameCategoryModal), findsNothing);
      expect(find.text('Create task'), findsOneWidget);
    },
  );
}
