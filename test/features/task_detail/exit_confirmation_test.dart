import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/features/task_detail/task_duration_modal.dart';
import 'package:amble/features/task_detail/task_name_category_modal.dart';
import 'package:amble/features/task_detail/task_start_time_modal.dart';

import '../../support/fake_notification_service.dart';

// Hive's real disk I/O hangs under flutter_test's synchronous pump-based
// zone unless routed through WidgetTester.runAsync — see docs/ERROR_LOG.md.
// Every tap that can trigger a save/delete, and the settle that follows it,
// runs inside the same runAsync zone so the real-time Hive write and the
// pump loop that observes its result don't race across zone boundaries.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    // pumpAndSettle only waits for frames, not real-zone I/O — a mutator's
    // continuation after `await saveTask(...)` (TaskList._refresh) can
    // still be queued on the real event loop here. Drain it explicitly
    // before this runAsync block (and the test) returns, or it resolves
    // later against an already-disposed ProviderContainer. See
    // docs/ERROR_LOG.md.
    await Future<void>.delayed(Duration.zero);
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
Future<void> _pumpCreateForm(WidgetTester tester, {required Box<Task> box}) async {
  final navigatorKey = await _pumpHost(tester, box: box);
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
  required Task task,
}) async {
  final navigatorKey = await _pumpHost(tester, box: box);
  showEditDetailsSheet(navigatorKey.currentContext!, task: task);
  await tester.pumpAndSettle();
}

/// The single create screen's Name/Category is reached by tapping the
/// preview card's pencil, which opens `TaskNameCategoryModal` — this
/// helper opens it, types [title], and confirms with Done, matching the
/// real tap-through rather than reaching into the widget tree directly.
///
/// A `showModalBottomSheet` modal is a route stacked ON TOP of the main
/// screen — the main screen's own widgets (including its Time/Duration
/// `TextField`s) stay mounted underneath and are still found by a bare
/// `find.byType(TextField)`, ahead of the modal's own fields in traversal
/// order. Established directly: `.first` silently landed typed text in
/// the wrong field entirely. Every finder here is scoped to descend from
/// the modal's own widget type instead.
Future<void> _nameTaskViaModal(WidgetTester tester, String title) async {
  await _tapAndSettle(tester, find.byIcon(Icons.edit_outlined));
  final nameField = find.descendant(
    of: find.byType(TaskNameCategoryModal),
    matching: find.byType(TextField),
  ).first;
  await tester.enterText(nameField, title);
  await tester.pumpAndSettle();
  // The modal is scrollable (a real fix for a real keyboard-open overflow
  // — see docs/ERROR_LOG.md), so with the on-screen keyboard's simulated
  // inset still applied, Done can sit below the visible viewport until
  // scrolled to. ensureVisible finds it wherever it currently sits before
  // the tap, rather than assuming a fixed on-screen position.
  final doneButton = find.descendant(
    of: find.byType(TaskNameCategoryModal),
    matching: find.text('Done'),
  );
  await tester.ensureVisible(doneButton);
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, doneButton);
}

/// Types [digits] (e.g. "0900") into the FIRST `TextField` inside
/// whichever of `TaskStartTimeModal`/`TaskDurationModal` is currently on
/// screen — passed as [modalType] since both stack over the same main
/// screen and its own Time/Duration fields the same way
/// `TaskNameCategoryModal` does (see `_nameTaskViaModal`'s doc comment).
Future<void> _fillSegmentedField(
  WidgetTester tester,
  String digits, {
  required Type modalType,
}) async {
  final field = find.descendant(
    of: find.byType(modalType),
    matching: find.byType(TextField),
  ).first;
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, digits);
  await tester.pumpAndSettle();
  // AppSegmentedTimeField only commits its value to `onChanged` on
  // blur/editing-complete, not on every keystroke — established directly
  // debugging this exact test (the value silently stayed null, so Done
  // treated the field as still unset). Unfocusing is what makes the
  // typed value actually land in the modal's own state.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  late Box<Task> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_exit_confirmation');
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
    'create flow: closing with an untouched, unnamed task closes silently, '
    'no dialog',
    (tester) async {
      await _pumpCreateForm(tester, box: box);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard this task?'), findsNothing);
      // The route itself is gone — the sheet's own title no longer shows.
      expect(find.text('Create task'), findsNothing);
    },
  );

  testWidgets(
    'create flow: naming the task via the pencil modal then closing still '
    'prompts, since a title is itself a real change from the empty default',
    (tester) async {
      await _pumpCreateForm(tester, box: box);

      await _nameTaskViaModal(tester, 'Buy milk');
      // Naming auto-advances into the Start-time modal — back out of it
      // without confirming, via the scrim, before closing the main screen.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard this task?'), findsOneWidget);
      expect(find.text('Discard draft'), findsOneWidget);
      expect(find.text('Discard changes'), findsNothing);
      // The cancel path is always offered, so a stray dismissal can never
      // lose work.
      expect(find.text('Keep editing'), findsOneWidget);
    },
  );

  testWidgets(
    'create flow: "Save task" saves via the same path as Confirm',
    (tester) async {
      await _pumpCreateForm(tester, box: box);

      // Naming the task auto-advances into the Start-time modal (the
      // guided first-run sequence), which auto-advances again into
      // Duration — see task_detail_sheet.dart's `_autoAdvanceEligible`.
      await _nameTaskViaModal(tester, 'Buy milk');
      await _fillSegmentedField(
        tester,
        '0900',
        modalType: TaskStartTimeModal,
      );
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(TaskStartTimeModal),
          matching: find.text('Done'),
        ),
      );
      await _fillSegmentedField(
        tester,
        '0030',
        modalType: TaskDurationModal,
      );
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(TaskDurationModal),
          matching: find.text('Done'),
        ),
      );

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
      await _tapAndSettle(tester, find.text('Save task'));

      expect(box.values.single.title, 'Buy milk');
      expect(box.values.single.isScheduled, isTrue);
    },
  );

  testWidgets(
    'create flow: "Discard draft" closes without persisting anything',
    (tester) async {
      await _pumpCreateForm(tester, box: box);

      await _nameTaskViaModal(tester, 'Buy milk');
      // Naming auto-advances into the Start-time modal. It has no close
      // icon of its own (it's a bottom sheet, like the wheel picker it
      // replaced) — tapping the scrim above it dismisses without
      // confirming, which stops the guided sequence there rather than
      // continuing into Duration.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
      await _tapAndSettle(tester, find.text('Discard draft'));

      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'create flow: "Keep editing" returns to the form, saving nothing and '
    'discarding nothing',
    (tester) async {
      await _pumpCreateForm(tester, box: box);

      await _nameTaskViaModal(tester, 'Buy milk');
      // Naming auto-advances into the Start-time modal — back out of it
      // without confirming before closing the main screen.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Keep editing'));

      // The dialog is gone, but the form is still open with the typed
      // title intact — cancel must be a true no-op, not a quiet save or
      // a quiet discard. The live preview card is what shows it now (the
      // name field itself lives inside a modal, not on this screen).
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
        category: TaskCategory.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(tester, box: box, task: task);

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
        category: TaskCategory.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(tester, box: box, task: task);

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
        category: TaskCategory.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(tester, box: box, task: task);

      await tester.enterText(find.byType(TextField).first, 'Renamed task');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Discard changes'));

      expect(box.values.single.title, 'Existing task');
    },
  );

  testWidgets(
    'edit details flow: "Save changes" saves the changed field',
    (tester) async {
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        category: TaskCategory.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditDetailsForm(tester, box: box, task: task);

      await tester.enterText(find.byType(TextField).first, 'Renamed task');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Save changes'));

      expect(box.values.single.title, 'Renamed task');
    },
  );
}
