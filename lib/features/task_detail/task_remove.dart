import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';

/// Which occurrences a "Remove" on a recurring task should affect.
enum RemoveScope { thisInstance, allInstances }

/// Removes [task] — the flow the action sheet's own "Remove" row and the
/// task edit screen's own delete button both trigger, kept in one place
/// so the recurring-scope disambiguation isn't duplicated between them. A
/// plain task removes immediately; a recurring one asks "this occurrence"
/// vs. "all occurrences" first (see [askRemoveScope]).
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
/// remove-scope sheet, never re-read afterward).
Future<void> removeTask(
  BuildContext context,
  TaskList notifier,
  Task task,
) async {
  if (!task.isRecurring) {
    await notifier.deleteTask(task.id);
    return;
  }

  final scope = await askRemoveScope(context);
  if (scope == null) return;

  switch (scope) {
    case RemoveScope.thisInstance:
      await notifier.deleteTask(task.id);
    case RemoveScope.allInstances:
      await notifier.deleteTaskSeries(task);
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
Future<RemoveScope?> askRemoveScope(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return AppSheet.show<RemoveScope>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

/// One row in the task action sheet / remove-scope sheet — an icon, a
/// label, and a tap target. Promoted alongside [removeTask] so both
/// sheets that use this exact row shape (`task_action_sheet.dart`'s own
/// menu, and [askRemoveScope]'s sheet) share one definition.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final AmbleTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? theme.colorTextPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingMd),
        child: Row(
          children: [
            Icon(icon, color: rowColor),
            SizedBox(width: theme.spacingMd),
            // Expanded so a long label wraps/ellipsises instead of
            // overflowing the row — the original labels were all short
            // enough to fit, but the remove-scope sheet's longer ones
            // ("Remove this occurrence") pushed it 56px over, which a
            // widget test caught as a RenderFlex overflow.
            Expanded(
              child: Text(
                label,
                style: theme.textBody.copyWith(
                  color: rowColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
