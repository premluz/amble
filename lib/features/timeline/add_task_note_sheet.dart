import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';

/// Opened by swiping right on a Timeline task row (Task/spatial and Zone/
/// non-spatial views only, never in Edit Mode) — a fast, single-field note
/// entry, distinct from the full Task Detail sheet's own notes field.
/// Requested directly: "slide right add note" (swipe-to-reveal, matching
/// the existing Inbox convention's own `AppSwipeActions`).
///
/// Notes are per-occurrence already, with no extra work needed here — see
/// `Task.notes`'s own field doc comment and CONSTITUTION.md's "materialized
/// instances, not virtual expansion": a recurring task's daily occurrences
/// are already separate Hive rows with independent `notes`/`scheduledAt`,
/// so two occurrences of the same tracked series on different days (or
/// the same day, for a sub-daily rule) never collide or need special
/// handling — this sheet just edits `task.notes` on the one row it was
/// opened from.
Future<void> showAddTaskNoteSheet(BuildContext context, Task task) {
  return AppSheet.show(
    context: context,
    builder: (sheetContext) => _AddTaskNoteSheetContent(task: task),
  );
}

class _AddTaskNoteSheetContent extends ConsumerStatefulWidget {
  const _AddTaskNoteSheetContent({required this.task});

  final Task task;

  @override
  ConsumerState<_AddTaskNoteSheetContent> createState() =>
      _AddTaskNoteSheetContentState();
}

class _AddTaskNoteSheetContentState
    extends ConsumerState<_AddTaskNoteSheetContent> {
  late final _controller = TextEditingController(text: widget.task.notes);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final notes = _controller.text.trim();
    widget.task.notes = notes.isEmpty ? null : notes;
    await ref.read(taskListProvider.notifier).updateTask(widget.task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        Text(widget.task.title, style: theme.textTitle),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: _controller,
          label: 'Note',
          maxLines: 4,
          autofocus: true,
        ),
        SizedBox(height: theme.spacingMd),
        AppButton(
          label: 'Save',
          size: AppButtonSize.lg,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
