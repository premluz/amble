import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_context_menu.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';

/// Which occurrences a "Remove" on a recurring task should affect.
enum RemoveScope { thisInstance, allInstances }

/// Removes [task] and shows an Undo toast — the flow the action sheet's
/// own "Remove" row, the task edit screen's own delete button, and the
/// Timeline's drag-to-delete-target all trigger, kept in one place so
/// neither the recurring-scope disambiguation nor the undo/restore logic
/// is duplicated across them. A plain task removes immediately; a
/// recurring one asks "this occurrence" vs. "all occurrences" first (see
/// [askRemoveScope]).
///
/// **Undo** (2026-09-22, requested directly: "let's build undo change
/// mechanism") — every affected row is snapshotted via [Task.toJson]
/// BEFORE the real delete runs, and the toast's `onUndo` restores each
/// one via [TaskList.updateTask] (a plain keyed re-save, since Hive keys
/// by id — this is the exact "re-save the same object" restore
/// [Task.fromJson] already proves correct for import). This is why the
/// snapshot has to happen here, in the ONE place that knows exactly which
/// rows [TaskList.deleteTask]/[TaskList.deleteTaskSeries] are about to
/// touch — a caller further out (the action sheet, the detail screen)
/// only ever sees `task`, not the whole series [deleteTaskSeries] can
/// silently reach past it.
///
/// A whole-series remove snapshots EVERY row [TaskList.deleteTaskSeries]
/// can touch, not just [task] — that method also MUTATES the template's
/// own recurrence fields (stripped, not deleted, when the template
/// itself survives as history) as a side effect of a series delete, so a
/// correct restore has to reverse that mutation too, not just re-create
/// whichever rows were actually removed.
///
/// Takes an already-resolved [notifier] rather than a `WidgetRef` — a
/// real bug, fixed directly, came from reading `ref` AFTER a pop that
/// unmounted the widget it was bound to ("Using 'ref' when a widget is
/// about to or has been unmounted is unsafe"), which threw silently and
/// aborted the delete. Taking the notifier as a plain value puts that
/// timing decision entirely in the caller's hands, the same way it was
/// fixed at this function's own original call site.
///
/// [context] must still be mounted when called (used only for the
/// remove-scope sheet, never re-read afterward). [rootContext] is the
/// CALLER's own surviving context — same "captured before any pop"
/// contract [showQuickCaptureSheet]'s own `rootContext` already
/// establishes — since two of this function's three call sites pop their
/// own sheet/screen before calling this, and the toast must outlive that.
Future<void> removeTask(
  BuildContext context,
  BuildContext rootContext,
  TaskList notifier,
  Task task,
) async {
  if (!task.isRecurring) {
    final snapshot = task.toJson();
    await notifier.deleteTask(task.id);
    if (!rootContext.mounted) return;
    AppUndoToast.show(
      context: rootContext,
      message: "Removed '${task.title}'",
      onUndo: () => notifier.updateTask(Task.fromJson(snapshot)),
    );
    return;
  }

  final scope = await askRemoveScope(context);
  if (scope == null) return;

  switch (scope) {
    case RemoveScope.thisInstance:
      final snapshot = task.toJson();
      await notifier.deleteTask(task.id);
      if (!rootContext.mounted) return;
      AppUndoToast.show(
        context: rootContext,
        message: "Removed '${task.title}'",
        onUndo: () => notifier.updateTask(Task.fromJson(snapshot)),
      );
    case RemoveScope.allInstances:
      // Every row the series delete could touch — not just `task` — see
      // this function's own doc comment on why the template's own
      // (possibly mutated, not deleted) row needs snapshotting too.
      final seriesSnapshots = notifier
          .tasksInSeries(task)
          .map((t) => t.toJson())
          .toList();
      await notifier.deleteTaskSeries(task);
      if (!rootContext.mounted) return;
      AppUndoToast.show(
        context: rootContext,
        message: 'Removed the whole series',
        onUndo: () => notifier.restoreTasksInBatch(
          seriesSnapshots.map(Task.fromJson),
        ),
      );
  }
}

/// Asks whether to remove just this occurrence or the whole series.
/// Returns null when dismissed without choosing.
///
/// An [AppSheet] rather than [AppAlertDialog] because this is a
/// three-way choice (this / all / dismiss) and the dialog primitive
/// returns `bool?` — two actions plus dismiss. The sheet is also the
/// same primitive the action menu this was launched from uses, so the
/// interaction reads as one continuous flow.
///
/// Built directly on [AppSheet] rather than [AppContextMenu] — the two
/// rows here both return a [RemoveScope] value through the sheet's own
/// `pop`, which [AppContextMenu]'s fire-and-forget `onTap` shape doesn't
/// fit, and this sheet also needs the heading/body text above its rows
/// that [AppContextMenu] doesn't provide.
Future<RemoveScope?> askRemoveScope(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return AppSheet.show<RemoveScope>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        Text(
          'This task repeats',
          style: theme.textTitle.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacingXs),
        Text(
          'Remove only this occurrence, or the whole series? Past '
          'occurrences are kept either way.',
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
        SizedBox(height: theme.spacingSm),
        ActionRow(
          theme: theme,
          icon: Icons.event_busy_outlined,
          label: 'Remove this occurrence',
          color: theme.colorTaskAlert,
          onTap: () => Navigator.of(sheetContext).pop(RemoveScope.thisInstance),
        ),
        ActionRow(
          theme: theme,
          icon: Icons.delete_sweep_outlined,
          label: 'Remove all occurrences',
          color: theme.colorTaskAlert,
          onTap: () => Navigator.of(sheetContext).pop(RemoveScope.allInstances),
        ),
      ],
    ),
  );
}
