import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:amble/features/task_detail/task_editor.dart';
import 'package:amble/features/task_detail/task_inspector_panel.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/task_inspector_host.dart';

/// The wide layout's right-hand create/edit panel — requested directly:
/// "on the right, if the user clicks an item, this is how they would create
/// it... if they click an existing one, this is how they would edit it."
/// `showTaskSheet` opens the shared editor there whenever a
/// [TaskInspectorPanel] is on screen, instead of a bottom sheet.

void main() {
  final boxes = TaskInspectorBoxes();
  late Box<Task> box;

  setUp(() async {
    await boxes.open('task_inspector');
    box = boxes.tasks;
  });

  tearDown(boxes.close);

  Future<GlobalKey<NavigatorState>> host(WidgetTester tester) =>
      boxes.pump(tester);

  Task taskNamed(String title, int hour) => Task.create(
    title: title,
    scheduledAt: daysFromToday(0, hour: hour),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.work,
  );

  final inPanel = find.descendant(
    of: find.byType(TaskInspectorPanel),
    matching: find.byType(TaskEditor),
  );

  String panelTitle(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: inPanel, matching: find.byType(TextField)).first,
      )
      .controller!
      .text;

  testWidgets('a task opens in the panel, not a bottom sheet', (tester) async {
    final task = taskNamed('Standup', 9);
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await host(tester);

    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();

    expect(inPanel, findsOneWidget);
    expect(panelTitle(tester), 'Standup');
    expect(navigatorKey.currentState!.canPop(), isFalse);
    // No "drag down to close" bar: that belongs to a sheet, not a panel.
    expect(
      find.descendant(of: inPanel, matching: find.byType(AppSheetHandle)),
      findsNothing,
    );
  });

  testWidgets('Save writes the edit and closes the panel', (tester) async {
    final task = taskNamed('Standup', 9);
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await host(tester);
    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: inPanel, matching: find.byType(TextField)).first,
      'Retro',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Save'));

    expect(box.get(task.id)!.title, 'Retro');
    expect(inPanel, findsNothing);
  });

  testWidgets('closing the panel with no edits closes it silently', (
    tester,
  ) async {
    final task = taskNamed('Standup', 9);
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await host(tester);
    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();
    expect(inPanel, findsOneWidget);

    await tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    expect(inPanel, findsNothing);
    expect(find.text('Discard'), findsNothing);
  });

  group('opening another task over unsaved edits asks first', () {
    Future<(Task, Task, BuildContext)> editFirstThenOpenSecond(
      WidgetTester tester,
    ) async {
      final first = taskNamed('Standup', 9);
      final second = taskNamed('Lunch', 12);
      await tester.runAsync(() async {
        await box.put(first.id, first);
        await box.put(second.id, second);
      });
      final navigatorKey = await host(tester);
      final context = navigatorKey.currentContext!;
      showTaskSheet(context, task: first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: inPanel, matching: find.byType(TextField)).first,
        'Retro',
      );
      await tester.pumpAndSettle();

      showTaskSheet(context, task: second);
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsOneWidget);
      return (first, second, context);
    }

    testWidgets('Keep editing stays on the first task, edits intact', (
      tester,
    ) async {
      await editFirstThenOpenSecond(tester);
      await tapAndSettle(tester, find.text('Keep editing'));

      expect(panelTitle(tester), 'Retro');
    });

    testWidgets('Discard drops the edits and opens the second task', (
      tester,
    ) async {
      final (first, _, _) = await editFirstThenOpenSecond(tester);
      await tapAndSettle(tester, find.text('Discard'));

      expect(panelTitle(tester), 'Lunch');
      expect(box.get(first.id)!.title, 'Standup');
    });
  });

  group('a Timeline quick-create draft opens in the panel', () {
    ProviderContainer containerOf(GlobalKey<NavigatorState> key) =>
        ProviderScope.containerOf(key.currentContext!, listen: false);

    Future<ProviderContainer> startDraft(
      WidgetTester tester, {
      bool showSheet = true,
    }) async {
      final container = containerOf(await host(tester));
      container
          .read(pendingTaskDraftProvider.notifier)
          .start(scheduledAt: daysFromToday(0, hour: 14), durationMinutes: 30);
      if (showSheet) {
        container.read(quickAddSheetVisibleProvider.notifier).show();
      }
      await tester.pumpAndSettle();
      return container;
    }

    PendingTaskDraft? editorDraft(WidgetTester tester) =>
        tester.widget<TaskEditor>(inPanel).draft;

    testWidgets('only once its sheet would show, not while the pill is held', (
      tester,
    ) async {
      final container = await startDraft(tester, showSheet: false);
      expect(inPanel, findsNothing);

      container.read(quickAddSheetVisibleProvider.notifier).show();
      await tester.pumpAndSettle();
      expect(inPanel, findsOneWidget);
      expect(panelTitle(tester), 'New thing');
    });

    testWidgets('the editor follows the pill as it moves', (tester) async {
      final container = await startDraft(tester);
      final moved = daysFromToday(0, hour: 15);
      container.read(pendingTaskDraftProvider.notifier).updatePosition(moved);
      await tester.pumpAndSettle();

      expect(editorDraft(tester)!.scheduledAt, moved);
    });

    testWidgets('Add saves it as a task, clears the draft and the panel', (
      tester,
    ) async {
      final container = await startDraft(tester);
      await tapAndSettle(tester, find.text('Add'));

      expect(box.values.single.title, 'New thing');
      expect(container.read(pendingTaskDraftProvider), isNull);
      expect(inPanel, findsNothing);
    });

    testWidgets('closing an untouched draft clears it, without asking', (
      tester,
    ) async {
      final container = await startDraft(tester);
      await tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Discard'), findsNothing);
      expect(container.read(pendingTaskDraftProvider), isNull);
      expect(inPanel, findsNothing);
      expect(box.values, isEmpty);
    });

    testWidgets('a draft started over unsaved edits asks; Keep editing '
        'cancels the draft', (tester) async {
      final task = taskNamed('Standup', 9);
      await tester.runAsync(() => box.put(task.id, task));
      final navigatorKey = await host(tester);
      final container = containerOf(navigatorKey);
      showTaskSheet(navigatorKey.currentContext!, task: task);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: inPanel, matching: find.byType(TextField)).first,
        'Retro',
      );
      await tester.pumpAndSettle();

      container
          .read(pendingTaskDraftProvider.notifier)
          .start(scheduledAt: daysFromToday(0, hour: 14), durationMinutes: 30);
      container.read(quickAddSheetVisibleProvider.notifier).show();
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsOneWidget);
      await tapAndSettle(tester, find.text('Keep editing'));

      expect(panelTitle(tester), 'Retro');
      expect(container.read(pendingTaskDraftProvider), isNull);
    });
  });
}
