import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'task_detail_sheet.dart';
import 'task_remove.dart';

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

  /// Pops this action sheet, then defers to the shared [removeTask] flow
  /// (`task_remove.dart`). `context`/`ref` are captured before the pop,
  /// for the same reason [removeTask]'s own doc comment gives: this
  /// sheet's element unmounts the instant it closes, and reading `ref`
  /// after that throws.
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final notifier = ref.read(taskListProvider.notifier);
    navigator.pop();
    await removeTask(navigator.context, notifier, task);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionRow(
          theme: theme,
          icon: Icons.edit_outlined,
          label: 'Edit task',
          onTap: () => _editTask(context),
        ),
        ActionRow(
          theme: theme,
          icon: Icons.content_copy_outlined,
          label: 'Duplicate',
          onTap: () => _duplicate(context),
        ),
        ActionRow(
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
