import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_alert_dialog.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../timeline/pending_task_draft_provider.dart'
    show PendingTaskDraft, pendingTaskDraftProvider;
import 'draft_form_link.dart';
import 'task_editor_body.dart';
import 'task_editor_form.dart';
import 'task_discard_dialog.dart';
import 'task_inspector.dart';
import 'task_remove.dart';
import 'task_sheet_form.dart';
import 'task_sheet_save.dart';

/// The task create/edit/duplicate editor — the same form, fields and save
/// wherever it's shown: inside a bottom sheet (`showTaskSheet`, phones) or
/// in the wide layout's right-hand panel ([TaskInspectorPanel]). It never
/// closes itself: it calls [onFinished] and the host does the closing.
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    required this.rootContext,
    required this.onFinished,
    this.task,
    this.duplicateFrom,
    this.templateId,
    this.initialScheduledAt,
    this.initialTimeOfDay,
    this.dialogContext,
    this.guardsRoutePop = false,
    this.inspector,
    this.draft,
  });

  /// Where the delete's undo toast anchors — the opener, which outlives
  /// this editor.
  final BuildContext rootContext;

  /// Closes whatever is showing this editor: pops the sheet, or empties
  /// the panel. Called after a save, a delete, or a confirmed close.
  final VoidCallback onFinished;

  final Task? task;
  final Task? duplicateFrom;
  final String? templateId;
  final DateTime? initialScheduledAt;
  final TimeOfDay? initialTimeOfDay;

  /// Where a repeating task's "which occurrences?" question shows after
  /// this editor is gone. Null uses the editor's own navigator (sheet).
  final BuildContext? dialogContext;

  /// Sheet only: Android back and a drag-down ask before discarding edits.
  final bool guardsRoutePop;

  /// Panel only: lets the panel ask this editor before replacing it with
  /// another task, so unsaved edits are never silently dropped.
  final TaskInspectorNotifier? inspector;

  /// A Timeline quick-create draft, live: the editor follows its pill and
  /// moves it (see [DraftFormLink]), and Add saves it as the draft.
  final PendingTaskDraft? draft;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  late final TaskSheetForm _form;
  DraftFormLink? _link;
  bool _isSaving = false;
  bool _hasSaved = false;

  bool get _creating => widget.task == null && widget.duplicateFrom == null;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _link = draft == null
        ? null
        : DraftFormLink(
            draft,
            drafts: ref.read(pendingTaskDraftProvider.notifier),
          );
    _form =
        _link?.form ??
        taskEditorForm(
          now: DateTime.now(),
          task: widget.task,
          duplicateFrom: widget.duplicateFrom,
          templateId: widget.templateId,
          initialScheduledAt: widget.initialScheduledAt,
          initialTimeOfDay: widget.initialTimeOfDay,
        );
    widget.inspector?.setLeaveGuard(_leaveForAnother);
  }

  @override
  void didUpdateWidget(TaskEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.draft;
    if (draft != null) _link?.follow(draft);
  }

  @override
  void dispose() {
    widget.inspector?.clearLeaveGuard(_leaveForAnother);
    _link?.dispose();
    _form.dispose();
    super.dispose();
  }

  /// Saves without closing. True once saved.
  Future<bool> _saveNow() async {
    if (_isSaving || _hasSaved || !_form.canSave) return _hasSaved;
    setState(() => _isSaving = true);
    try {
      _hasSaved = await saveTaskSheet(
        context,
        ref,
        _form,
        draftId: _link?.draftId,
      );
      return _hasSaved;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    if (await _saveNow() && mounted) widget.onFinished();
  }

  /// True when this editor may go away: nothing unsaved, or the user chose
  /// to save or discard. Asks first when there are edits.
  Future<bool> _confirmLeave() async {
    final unsaved = _link?.hasTypedName ?? _form.hasChanges;
    if (_hasSaved || !unsaved) return true;
    final choice = await confirmDiscardTask(context);
    if (!mounted) return false;
    switch (choice) {
      case AppAlertDialogChoice.primary:
        return _saveNow();
      case AppAlertDialogChoice.destructive:
        _hasSaved = true;
        return true;
      case AppAlertDialogChoice.cancel:
        return false;
    }
  }

  /// The panel's check before showing something else here. A draft that
  /// may go is finished too, so its pill leaves the Timeline with it.
  Future<bool> _leaveForAnother() async {
    final ok = await _confirmLeave();
    if (ok && _link != null && mounted) widget.onFinished();
    return ok;
  }

  Future<void> _requestClose() async {
    if (await _confirmLeave() && mounted) widget.onFinished();
  }

  /// The shared remove flow; asks which occurrences for a repeating task.
  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final dialogContext = widget.dialogContext ?? Navigator.of(context).context;
    final notifier = ref.read(taskListProvider.notifier);
    _hasSaved = true;
    widget.onFinished();
    await removeTask(dialogContext, widget.rootContext, notifier, task);
  }

  @override
  Widget build(BuildContext context) {
    return TaskEditorBody(
      form: _form,
      isSaving: _isSaving,
      editing: widget.task != null,
      creating: _creating,
      inPanel: widget.inspector != null,
      // A draft opens without the keyboard, like phone quick-create.
      autofocusName: _creating && _link == null,
      onClose: _requestClose,
      onDelete: () => unawaited(_delete()),
      onSave: _save,
      onNameFocusChanged: _link?.clearDefaultName,
      canPopSilently: widget.guardsRoutePop
          ? () => _hasSaved || !_form.hasChanges
          : null,
    );
  }
}
