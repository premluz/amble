import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_delete_puff.dart';
import 'task_sheet_form.dart';

/// The task editor header's trailing buttons: a trash button when editing
/// an existing task, then Add (create/duplicate) or Save (edit).
class TaskEditorActions extends StatelessWidget {
  const TaskEditorActions({
    super.key,
    required this.form,
    required this.isSaving,
    required this.editing,
    required this.onDelete,
    required this.onSave,
  });

  final TaskSheetForm form;
  final bool isSaving;

  /// Editing an existing task: shows the trash button, and labels the
  /// primary button Save rather than Add.
  final bool editing;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editing) ...[
            Builder(
              builder: (buttonContext) => AppButton(
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.ghost,
                shape: AppButtonShape.circle,
                tooltip: 'Delete task',
                iconColor: theme.colorDestructive,
                onPressed: () {
                  AppDeletePuff.show(context: buttonContext);
                  onDelete();
                },
              ),
            ),
            SizedBox(width: theme.spacingSm),
          ],
          AppButton(
            label: editing ? 'Save' : 'Add',
            size: AppButtonSize.md,
            shape: AppButtonShape.pill,
            isLoading: isSaving,
            onPressed: form.canSave ? onSave : null,
          ),
        ],
      ),
    );
  }
}
