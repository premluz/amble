import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_alert_dialog.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'task_discard_dialog.dart';
import 'task_duration_modal.dart';
import 'task_remove.dart';
import 'task_sheet_fields.dart';
import 'task_sheet_form.dart';
import 'task_sheet_save.dart';

/// The compact task sheet for a task opened from anywhere: edit [task]
/// (Save, and a trash button), duplicate [duplicateFrom] or create — the
/// same fields and save as the Timeline's in-place sheet. [templateId]
/// records the preset a duplicate came from. A Things item without a time
/// yet opens with Time and Duration unset; Save waits for both.
Future<void> showTaskSheet(
  BuildContext context, {
  Task? task,
  Task? duplicateFrom,
  String? templateId,
  DateTime? initialScheduledAt,
  TimeOfDay? initialTimeOfDay,
}) {
  final creating = task == null && duplicateFrom == null;
  return AppSheet.show<void>(
    context: context,
    autofocusesKeyboard: creating,
    builder: (_) => _TaskSheet(
      // The caller's context: the delete's undo toast anchors there, since
      // this sheet is gone by then.
      rootContext: context,
      task: task,
      duplicateFrom: duplicateFrom,
      templateId: templateId,
      initialScheduledAt: initialScheduledAt,
      initialTimeOfDay: initialTimeOfDay,
    ),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({
    required this.rootContext,
    this.task,
    this.duplicateFrom,
    this.templateId,
    this.initialScheduledAt,
    this.initialTimeOfDay,
  });

  final BuildContext rootContext;
  final Task? task;
  final Task? duplicateFrom;
  final String? templateId;
  final DateTime? initialScheduledAt;
  final TimeOfDay? initialTimeOfDay;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TaskSheetForm _form;
  bool _isSaving = false;
  bool _hasSaved = false;

  bool get _creating => widget.task == null && widget.duplicateFrom == null;

  @override
  void initState() {
    super.initState();
    _form = TaskSheetForm(
      allTasks: ref.read(taskListProvider),
      task: widget.task,
      duplicateFrom: widget.duplicateFrom,
      templateId: widget.templateId,
      date: widget.initialScheduledAt,
      // A brand-new task starts at noon for five minutes, as the old full
      // sheet did once its name was in; a Things item keeps its gaps.
      time:
          widget.initialTimeOfDay ??
          (_creating ? const TimeOfDay(hour: 12, minute: 0) : null),
      durationMinutes: _creating ? presetMinutes.first : null,
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _hasSaved || !_form.canSave) return;
    setState(() => _isSaving = true);
    try {
      _hasSaved = await saveTaskSheet(context, ref, _form);
      if (_hasSaved && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Closing with edits asks first — from ×, Android back, or a drag down.
  Future<void> _confirmClose() async {
    final choice = await confirmDiscardTask(context);
    if (!mounted) return;
    switch (choice) {
      case AppAlertDialogChoice.primary:
        await _save();
      case AppAlertDialogChoice.destructive:
        _hasSaved = true;
        Navigator.of(context).pop();
      case AppAlertDialogChoice.cancel:
        break;
    }
  }

  /// The shared remove flow (`task_remove.dart`), which asks which
  /// occurrences for a repeating task.
  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final navigator = Navigator.of(context);
    final notifier = ref.read(taskListProvider.notifier);
    _hasSaved = true;
    navigator.pop();
    await removeTask(navigator.context, widget.rootContext, notifier, task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ListenableBuilder(
      listenable: _form,
      builder: (context, child) => PopScope(
        canPop: _hasSaved || !_form.hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmClose();
        },
        child: child!,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            theme: theme,
            title: null,
            onClose: () => Navigator.of(context).maybePop(),
            trailing: _actions(theme),
          ),
          SizedBox(height: SheetTokens.headerToFieldGap(theme)),
          TaskSheetFields(
            form: _form,
            showPreset: widget.task == null,
            autofocusName: _creating,
            titlePlaceholder: _creating ? 'New thing' : 'Add title',
          ),
        ],
      ),
    );
  }

  Widget _actions(AmbleTheme theme) => ListenableBuilder(
    listenable: _form,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.task != null) ...[
          AppButton(
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.ghost,
            shape: AppButtonShape.circle,
            tooltip: 'Delete task',
            iconColor: theme.colorDestructive,
            onPressed: _delete,
          ),
          SizedBox(width: theme.spacingSm),
        ],
        AppButton(
          label: widget.task == null ? 'Add' : 'Save',
          size: AppButtonSize.md,
          shape: AppButtonShape.pill,
          isLoading: _isSaving,
          onPressed: _form.canSave ? _save : null,
        ),
      ],
    ),
  );
}
