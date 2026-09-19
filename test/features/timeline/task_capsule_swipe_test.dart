import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';

/// Swipe-left (mark done/undone) and swipe-right (add note) on Timeline
/// task rows — requested directly: "on tasks we need also slide left
/// done, longer left add note[/]slide right add note... on timeline
/// spatial and non spatial only (not on edit)." Resolved via AskUserQuestion
/// to: swipe-right adds a note (not a second threshold on the left), swipe
/// left toggles done/undone via the existing onToggleComplete callback.
///
/// Also covers the real gesture-arena bug this feature exposed and fixed:
/// AppSwipeActions previously installed its HorizontalDragGestureRecognizer
/// unconditionally even with both actions null, which interrupted a
/// sibling ResizeHandle's own vertical drag mid-gesture once this widget
/// started wrapping Timeline rows that already own drag gestures — see
/// app_swipe_actions.dart's own updated doc comment and
/// task_capsule_resize_handle_test.dart, which caught the regression.
void main() {
  final pendingTask = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 90,
    categoryId: BuiltInCategoryIds.work,
  );

  final completedTask = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 90,
    categoryId: BuiltInCategoryIds.work,
  )..status = TaskStatus.completed;

  Future<void> pump(
    WidgetTester tester, {
    required Task task,
    VoidCallback? onToggleComplete,
    VoidCallback? onAddNote,
    bool editModeEnabled = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            onToggleComplete: onToggleComplete,
            onAddNote: onAddNote,
            editModeEnabled: editModeEnabled,
          ),
        ),
      ),
    );
  }

  testWidgets('outside Edit Mode, both swipe actions are wired', (
    tester,
  ) async {
    await pump(
      tester,
      task: pendingTask,
      onToggleComplete: () {},
      onAddNote: () {},
    );

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.startAction, isNotNull);
    expect(swipe.endAction, isNotNull);
  });

  testWidgets('in Edit Mode, both swipe actions are disabled regardless of '
      'callbacks passed', (tester) async {
    await pump(
      tester,
      task: pendingTask,
      onToggleComplete: () {},
      onAddNote: () {},
      editModeEnabled: true,
    );

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.startAction, isNull);
    expect(swipe.endAction, isNull);
  });

  testWidgets('the end (swipe-left) action shows "mark done" on a pending '
      'task', (tester) async {
    var toggled = false;
    await pump(
      tester,
      task: pendingTask,
      onToggleComplete: () => toggled = true,
    );

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.endAction!.semanticLabel, 'Mark done');
    swipe.endAction!.onActivate();
    expect(toggled, isTrue);
  });

  testWidgets('the end (swipe-left) action shows "mark undone" on a '
      'completed task', (tester) async {
    await pump(tester, task: completedTask, onToggleComplete: () {});

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.endAction!.semanticLabel, 'Mark undone');
  });

  testWidgets('the start (swipe-right) action is "add note" and calls '
      'onAddNote', (tester) async {
    var noteRequested = false;
    await pump(tester, task: pendingTask, onAddNote: () => noteRequested = true);

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.startAction!.semanticLabel, 'Add note');
    swipe.startAction!.onActivate();
    expect(noteRequested, isTrue);
  });

  testWidgets('a null onToggleComplete/onAddNote leaves the matching side '
      'disabled, matching every other optional callback on this widget', (
    tester,
  ) async {
    await pump(tester, task: pendingTask);

    final swipe = tester.widget<AppSwipeActions>(find.byType(AppSwipeActions));
    expect(swipe.startAction, isNull);
    expect(swipe.endAction, isNull);
  });

  testWidgets('a resize handle\'s own vertical drag still fires end-to-end '
      'once this row is wrapped in AppSwipeActions — the gesture-arena '
      'regression this feature exposed and fixed', (tester) async {
    var resizeStarted = false;
    var resizeUpdated = false;
    var resizeEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: pendingTask,
            editModeEnabled: true,
            isSelected: true,
            onToggleComplete: () {},
            onAddNote: () {},
            onResizeStart: (_) => resizeStarted = true,
            onResizeUpdate: (_) => resizeUpdated = true,
            onResizeEnd: (_) => resizeEnded = true,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ResizeHandle), const Offset(0, 20));
    await tester.pump();

    expect(resizeStarted, isTrue);
    expect(resizeUpdated, isTrue);
    expect(resizeEnded, isTrue);
  });
}
