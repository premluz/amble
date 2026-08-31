import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'task_detail_sheet.dart';

/// The mobile action-menu bottom sheet for a single scheduled task, opened
/// by tapping a task on the Timeline. Presented via [AppSheet] (the
/// adaptive bottom-sheet primitive) rather than a raw
/// `showModalBottomSheet`/`showCupertinoModalPopup`, per design principle 4.
Future<void> showTaskActionSheet(BuildContext context, {required Task task}) {
  return AppSheet.show<void>(
    context: context,
    builder: (context) => _TaskActionSheetContent(task: task),
  );
}

/// Which occurrences a "Remove" on a recurring task should affect.
enum _RemoveScope { thisInstance, allInstances }

class _TaskActionSheetContent extends ConsumerWidget {
  const _TaskActionSheetContent({required this.task});

  final Task task;

  /// Opens the same screen "Create task" uses, pre-populated — requested
  /// directly, replacing the old two-entry "Edit details"/"Edit time and
  /// duration" split with a single "Edit task" that shows every field at
  /// once. `showTaskDetailSheet(task: ...)` already skips stage 1 (the
  /// Name-only step) for any non-null task and lands directly on the full
  /// form.
  Future<void> _editTask(BuildContext context) async {
    Navigator.of(context).pop();
    await showTaskDetailSheet(context, task: task);
  }

  /// Opens the create screen pre-filled from [task], WITHOUT persisting
  /// anything yet — fixed directly: the previous version called
  /// `duplicateTask` (a real repository write) immediately on tap, before
  /// the follow-up screen even opened, so closing/discarding it still
  /// left an unwanted duplicate behind. Now nothing is saved until the
  /// user actually confirms on the (pre-filled) create screen, same as
  /// every other create path in this app.
  Future<void> _duplicate(BuildContext context) async {
    Navigator.of(context).pop();
    await showTaskDetailSheet(context, duplicateFrom: task);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    // Captured BEFORE the pop: `context` here is this sheet's own, so it
    // stops being mounted the moment the sheet closes — a `context.mounted`
    // check afterwards would just silently skip the follow-up sheet. The
    // enclosing navigator outlives the sheet and is what the second sheet
    // has to be pushed onto.
    final navigator = Navigator.of(context);
    // The notifier is read BEFORE the pop, for the same reason as the
    // navigator: `ref` is bound to this sheet's element, and reading it
    // after the sheet unmounts throws ("Using 'ref' when a widget is
    // about to or has been unmounted is unsafe"). That threw silently
    // inside the async gap and aborted the delete — reported as Remove
    // not working. Both handles have to be captured while still mounted.
    final notifier = ref.read(taskListProvider.notifier);
    navigator.pop();

    // A plain task removes immediately, unchanged. A recurring one asks
    // first — requested directly: removing a repeated task should offer
    // "this instance" vs "all instances", since deleting a whole series
    // by accident is not something a user can undo here.
    if (!task.isRecurring) {
      await notifier.deleteTask(task.id);
      return;
    }

    final scope = await _askRemoveScope(navigator.context);
    if (scope == null) return;

    switch (scope) {
      case _RemoveScope.thisInstance:
        await notifier.deleteTask(task.id);
      case _RemoveScope.allInstances:
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
  Future<_RemoveScope?> _askRemoveScope(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return AppSheet.show<_RemoveScope>(
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
          _ActionRow(
            theme: theme,
            icon: Icons.event_busy_outlined,
            label: 'Remove this occurrence',
            color: theme.colorTaskAlert,
            onTap: () =>
                Navigator.of(sheetContext).pop(_RemoveScope.thisInstance),
          ),
          _ActionRow(
            theme: theme,
            icon: Icons.delete_sweep_outlined,
            label: 'Remove all occurrences',
            color: theme.colorTaskAlert,
            onTap: () =>
                Navigator.of(sheetContext).pop(_RemoveScope.allInstances),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionRow(
          theme: theme,
          icon: Icons.edit_outlined,
          label: 'Edit task',
          onTap: () => _editTask(context),
        ),
        _ActionRow(
          theme: theme,
          icon: Icons.content_copy_outlined,
          label: 'Duplicate',
          onTap: () => _duplicate(context),
        ),
        _ActionRow(
          theme: theme,
          icon: Icons.delete_outline_rounded,
          label: 'Remove',
          // Reuses the existing destructive token (colorTaskAlert), the
          // same one AppAlertDialog uses for its destructive actions —
          // no new color token needed for this.
          color: theme.colorTaskAlert,
          onTap: () => _remove(context, ref),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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
