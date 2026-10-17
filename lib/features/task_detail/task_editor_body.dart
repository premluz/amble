import 'package:flutter/material.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet_header.dart';
import 'task_editor_actions.dart';
import 'task_sheet_fields.dart';
import 'task_sheet_form.dart';

/// The task editor's layout — header (close, trash, Add/Save) over the
/// shared fields. Stateless: `TaskEditor` owns every decision and passes
/// them in, so the sheet and the panel can't lay the editor out
/// differently.
class TaskEditorBody extends StatelessWidget {
  const TaskEditorBody({
    super.key,
    required this.form,
    required this.isSaving,
    required this.editing,
    required this.creating,
    required this.inPanel,
    required this.autofocusName,
    required this.onClose,
    required this.onDelete,
    required this.onSave,
    this.onNameFocusChanged,
    this.canPopSilently,
  });

  final TaskSheetForm form;
  final bool isSaving;

  /// An existing task: trash button, and Save rather than Add.
  final bool editing;

  /// A new item: "New thing" as the name placeholder.
  final bool creating;

  /// In the wide layout's panel: no "drag down to close" bar, which
  /// belongs to a sheet. The settings are the same chips as the phone's.
  final bool inPanel;

  final bool autofocusName;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final ValueChanged<bool>? onNameFocusChanged;

  /// Sheet only: whether back or a drag-down may close it without asking.
  /// When it returns false, the pop is held and [onClose] asks instead.
  /// Null (the panel) adds no guard.
  final bool Function()? canPopSilently;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final placeholder = creating ? 'New thing' : 'Add title';
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          theme: theme,
          title: null,
          onClose: onClose,
          showHandle: !inPanel,
          trailing: TaskEditorActions(
            form: form,
            isSaving: isSaving,
            editing: editing,
            onDelete: onDelete,
            onSave: onSave,
          ),
        ),
        SizedBox(height: SheetTokens.headerToFieldGap(theme)),
        TaskSheetFields(
          form: form,
          showPreset: !editing,
          autofocusName: autofocusName,
          titlePlaceholder: placeholder,
          onNameFocusChanged: onNameFocusChanged,
        ),
      ],
    );
    final canPop = canPopSilently;
    if (canPop == null) return body;
    return ListenableBuilder(
      listenable: form,
      builder: (context, child) => PopScope(
        canPop: canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onClose();
        },
        child: child!,
      ),
      child: body,
    );
  }
}
