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
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

// Hive's real disk I/O hangs under flutter_test's synchronous pump-based
// zone unless routed through WidgetTester.runAsync — see docs/ERROR_LOG.md.
// Every tap that can trigger a save/delete, and the settle that follows it,
// runs inside the same runAsync zone so the real-time Hive write and the
// pump loop that observes its result don't race across zone boundaries.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    // Not pumpAndSettle here: a tap that triggers _save() flips
    // _isSaving, and the Save button's spinner (AppButton.isLoading)
    // animates continuously while a save is in flight — pumpAndSettle
    // would time out waiting for an animation that never settles. A
    // single pump just drains the tap's own frame.
    await tester.pump();
    // pumpAndSettle only waits for frames, not real-zone I/O — a mutator's
    // continuation after `await saveTask(...)` (TaskList._refresh) can
    // still be queued on the real event loop here. Drain it explicitly
    // before this runAsync block (and the test) returns, or it resolves
    // later against an already-disposed ProviderContainer. See
    // docs/ERROR_LOG.md.
    await Future<void>.delayed(Duration.zero);
    // Drains the pop's route-transition animation and the post-pop
    // `setState(() => _isSaving = false)`, both of which settle once the
    // save itself has completed above.
    await tester.pumpAndSettle();
  });
}

/// Fixed `false` so this suite's overlap-agnostic scenarios don't need to
/// touch a real `preferences` Hive box.
class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
}) async {
  // The create flow now opens per-field modal sheets ON TOP of the main
  // screen — at the default 800x600 (LOGICAL) test surface, a full-height
  // sheet's rendered position and its hit-test position can disagree
  // (established directly: see docs/ERROR_LOG.md, "A tap that 'does
  // nothing' in a widget test may be missing the target entirely"). A
  // real phone-sized viewport avoids that class of bug outright.
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
        // This suite doesn't exercise overlap behavior and has no real
        // `preferences` Hive box open — override rather than let the
        // provider's default-true build() hit `preferencesRepositoryProvider`
        // and throw on a missing box. See docs/DECISIONS.md.
        preventOverlappingTasksSettingProvider.overrideWith(
          () => _NoopPreventOverlappingTasksSetting(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        // showTaskDetailSheet/showEditDetailsSheet always push their route
        // on top of something — it can't be the Navigator's only route, or
        // popping it has nowhere to go.
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  return navigatorKey;
}

/// Pumps the **create** wizard's first (details) step — title typing and
/// the close (×) button both live here, matching every test below that
/// only ever touches the title.
Future<void> _pumpCreateForm(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
}) async {
  final navigatorKey = await _pumpHost(
    tester,
    box: box,
    categoryBox: categoryBox,
  );
  showTaskDetailSheet(
    navigatorKey.currentContext!,
    initialScheduledAt: DateTime(2026, 8, 20, 9),
  );
  await tester.pumpAndSettle();
}

/// Pumps the standalone "Edit details" modal for [task].
Future<void> _pumpEditDetailsForm(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Task task,
}) async {
  final navigatorKey = await _pumpHost(
    tester,
    box: box,
    categoryBox: categoryBox,
  );
  showEditDetailsSheet(navigatorKey.currentContext!, task: task);
  await tester.pumpAndSettle();
}

/// The create flow's stage 1 is the Name field directly on the sheet
/// itself (no modal any more — see task_detail_sheet.dart's `_isNameStage`)
/// — this helper types [title] into it and confirms with Done, advancing
/// into stage 2's full form.
Future<void> _nameTaskViaModal(WidgetTester tester, String title) async {
  // NOT find.widgetWithText(TextField, 'Task name') — that finder needs
  // the label text as a DESCENDANT of the TextField, but AppFieldShell
  // renders the floating label and the TextField as siblings. Descending
  // through the AppTextField itself (whose subtree contains both) is what
  // actually locates the real field.
  final nameField = find.descendant(
    of: find.widgetWithText(AppTextField, 'Task name'),
    matching: find.byType(TextField),
  );
  await tester.enterText(nameField, title);
  await tester.pumpAndSettle();
  final doneButton = find.text('Done');
  await tester.ensureVisible(doneButton);
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, doneButton);
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_exit_confirmation');
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

  testWidgets(
    'create flow: closing with an untouched, unnamed task closes silently, '
    'no dialog',
    (tester) async {
      await _pumpCreateForm(tester, box: box, categoryBox: categoryBox);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard this task?'), findsNothing);
      // The route itself is gone — the sheet's own title no longer shows.
      expect(find.text('Create task'), findsNothing);
    },
  );

  testWidgets('create flow: the system back gesture (Android edge swipe) on an '
      'untouched, unnamed stage-1 task closes the whole sheet — same as '
      'Done/the close button, not just a keyboard dismiss', (tester) async {
    // Real bug, reported directly: "on task creation when nothing added
    // no letter and swipe is done it closes keyboard only but should
    // actually close both keyboard and modal, same as Done does." The
    // route had no PopScope at all, so Navigator.maybePop (what the
    // system back gesture ultimately drives) popped straight through
    // without ever running _handleClose — the same method Done and the
    // close (X) button both already use, which is what makes an empty
    // stage-1 task close silently instead of prompting.
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showTaskDetailSheet(
      navigatorKey.currentContext!,
      initialScheduledAt: DateTime(2026, 8, 20, 9),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create task'), findsOneWidget);

    await tester.runAsync(() async {
      await navigatorKey.currentState!.maybePop();
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    expect(find.text('Discard this task?'), findsNothing);
    // The whole sheet closed, not just its keyboard — the route itself
    // is gone.
    expect(find.text('Create task'), findsNothing);
  });

  testWidgets(
    'create flow: the system back gesture after naming the task prompts '
    'to discard, exactly like the close button does',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showTaskDetailSheet(
        navigatorKey.currentContext!,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      );
      await tester.pumpAndSettle();

      await _nameTaskViaModal(tester, 'Buy milk');

      await tester.runAsync(() async {
        await navigatorKey.currentState!.maybePop();
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(find.text('Discard this task?'), findsOneWidget);
      // The route is still there behind the dialog — a back gesture on a
      // real draft must never silently lose it.
      expect(find.text('Create task'), findsOneWidget);
    },
  );

  testWidgets(
    'create flow: naming the task via stage 1 then closing still prompts, '
    'since a title is itself a real change from the empty default',
    (tester) async {
      await _pumpCreateForm(tester, box: box, categoryBox: categoryBox);

      await _nameTaskViaModal(tester, 'Buy milk');
      // No modal chaining any more — confirming stage 1's name lands
      // directly on stage 2's full form, ready to close from there.
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard this task?'), findsOneWidget);
      expect(find.text('Discard draft'), findsOneWidget);
      expect(find.text('Discard changes'), findsNothing);
      // The cancel path is always offered, so a stray dismissal can never
      // lose work.
      expect(find.text('Keep editing'), findsOneWidget);
    },
  );

  testWidgets('create flow: "Save task" saves via the same path as Confirm', (
    tester,
  ) async {
    await _pumpCreateForm(tester, box: box, categoryBox: categoryBox);

    // Naming advances stage 1 -> stage 2, where Time and Duration both
    // default immediately (Time to "now" rounded to 5 minutes, Duration
    // to the 5-minute preset) — no further taps needed to give the task
    // a real, savable schedule.
    await _nameTaskViaModal(tester, 'Buy milk');

    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    await _tapAndSettle(tester, find.text('Save task'));

    expect(box.values.single.title, 'Buy milk');
    expect(box.values.single.isScheduled, isTrue);
  });

  testWidgets(
    'create flow: "Discard draft" closes without persisting anything',
    (tester) async {
      await _pumpCreateForm(tester, box: box, categoryBox: categoryBox);

      await _nameTaskViaModal(tester, 'Buy milk');

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
      await _tapAndSettle(tester, find.text('Discard draft'));

      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'create flow: "Keep editing" returns to the form, saving nothing and '
    'discarding nothing',
    (tester) async {
      await _pumpCreateForm(tester, box: box, categoryBox: categoryBox);

      await _nameTaskViaModal(tester, 'Buy milk');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Keep editing'));

      // The dialog is gone, but the form is still open with the typed
      // title intact — cancel must be a true no-op, not a quiet save or
      // a quiet discard. The live preview card is what shows it now.
      expect(find.text('Discard this task?'), findsNothing);
      expect(find.text('Buy milk'), findsOneWidget);
      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'edit details flow: closing with no changes made closes silently, '
    'no dialog',
    (tester) async {
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(
        tester,
        box: box,
        categoryBox: categoryBox,
        task: task,
      );

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard this task?'), findsNothing);
    },
  );

  testWidgets(
    'edit details flow: a changed field prompts with "Discard changes", '
    'not "Discard draft"',
    (tester) async {
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(
        tester,
        box: box,
        categoryBox: categoryBox,
        task: task,
      );

      await tester.enterText(find.byType(TextField).first, 'Renamed task');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Discard changes'), findsOneWidget);
      expect(find.text('Discard draft'), findsNothing);
      expect(find.text('Keep editing'), findsOneWidget);
    },
  );

  testWidgets(
    'edit details flow: "Discard changes" leaves the originally saved '
    'task untouched — it is not deleted',
    (tester) async {
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(
        tester,
        box: box,
        categoryBox: categoryBox,
        task: task,
      );

      await tester.enterText(find.byType(TextField).first, 'Renamed task');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Discard changes'));

      expect(box.values.single.title, 'Existing task');
    },
  );

  testWidgets('edit details flow: "Save changes" saves the changed field', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Existing task',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpEditDetailsForm(
      tester,
      box: box,
      categoryBox: categoryBox,
      task: task,
    );

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    await _tapAndSettle(tester, find.text('Save changes'));

    expect(box.values.single.title, 'Renamed task');
  });
}
