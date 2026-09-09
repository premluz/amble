import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_staggered_entrance.dart';
import '../../core/widgets/app_step_scaffold.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_template_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../task_detail/task_duration_modal.dart';
import 'task_template_form_panes.dart';

/// Opens the create/edit form for a [TaskTemplate] — [template] null to
/// create, non-null to edit that row.
///
/// Near-full-screen, built on [StepScaffold] — the exact same chrome (and,
/// on create, the exact same Name-only stage 1 that reveals everything
/// else on "Done") the real task-creation flow and Zone's own add/edit
/// screen already use. Requested directly: "add template and add tracked
/// should follow same modal UI and interaction model as add task and add
/// zone." Reverses this feature's own earlier choice of [AppSheet] (a
/// half-height sheet, reasoned at the time as "four short fields don't
/// justify a full-screen takeover") — that reasoning no longer holds once
/// consistency with every other create flow in the app is the actual
/// requirement.
///
/// All writes go through `taskTemplateListProvider`; this UI never touches
/// the repository or Hive directly.
Future<void> showTaskTemplateForm(
  BuildContext context, {
  TaskTemplate? template,
}) {
  return pushAppSheetRoute<void>(
    context,
    (context) => _TaskTemplateForm(template: template),
  );
}

class _TaskTemplateForm extends ConsumerStatefulWidget {
  const _TaskTemplateForm({this.template});

  /// The row being edited, or null for a create. Save writes back to this
  /// same id when set, rather than creating a second template.
  final TaskTemplate? template;

  @override
  ConsumerState<_TaskTemplateForm> createState() => _TaskTemplateFormState();
}

class _TaskTemplateFormState extends ConsumerState<_TaskTemplateForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _categoryId;
  int? _durationMinutes;
  String? _behaviorId;
  bool _isSaving = false;

  /// See [TaskTemplate.isImportant] — carried onto any task spawned from
  /// this template, same as category/duration/notes already are.
  /// Requested directly: "under templates, add a checkbox... we already
  /// have this flag."
  bool _isImportant = false;

  /// Stage 1 (Name only) vs. stage 2 (everything else) — matches
  /// `task_detail_sheet.dart`/`zone_form_screen.dart`'s own create-flow
  /// pattern exactly. Editing an existing template skips straight to
  /// stage 2, same as "Edit task"/"Edit zone" do — there is nothing to
  /// stage for a template that already has every field filled in.
  bool _isNameStage = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '')
      // Same fix `zone_form_screen.dart`'s own Name field needed: nothing
      // here otherwise rebuilds on the controller's own text changing, so
      // the stage-1 Done button stayed disabled while typing. AppTextField
      // has no onChanged of its own, so this listens to the controller
      // directly instead.
      ..addListener(() => setState(() {}));
    _notesController = TextEditingController(text: template?.notes ?? '');
    // General for a fresh template — the same neutral default the task
    // detail sheet's own create path uses, rather than silently picking
    // one of the real categories.
    _categoryId = template?.categoryId ?? BuiltInCategoryIds.general;
    _durationMinutes = template?.durationMinutes;
    _behaviorId = template?.behaviorId;
    _isImportant = template?.isImportant ?? false;
    _isNameStage = template == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Only the title is required. Duration stays genuinely optional — it is
  /// a prefill suggestion for a spawned task, not an enforced value (see
  /// [TaskTemplate.durationMinutes]), so an unset one is a real state
  /// rather than a number to silently fill in.
  bool get _canSave => _titleController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _pickDuration() async {
    final minutes = await TaskDurationModal.show(
      context: context,
      initialMinutes: _durationMinutes,
    );
    if (minutes == null) return;
    setState(() => _durationMinutes = minutes);
  }

  /// Confirms stage 1 (Name) and advances to stage 2 — fired by stage 1's
  /// own Done button or the Name field's keyboard-complete action. Mirrors
  /// `zone_form_screen.dart`'s own `_confirmNameStage` exactly: an empty
  /// name at this point closes the whole screen instead of advancing to a
  /// form with nothing in it.
  void _confirmNameStage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isNameStage = false);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final notes = _notesController.text.trim();
      final notifier = ref.read(taskTemplateListProvider.notifier);
      final existing = widget.template;

      if (existing == null) {
        await notifier.createTemplate(
          title: _titleController.text.trim(),
          categoryId: _categoryId,
          durationMinutes: _durationMinutes,
          notes: notes.isEmpty ? null : notes,
          behaviorId: _behaviorId,
          isImportant: _isImportant,
        );
      } else {
        existing.title = _titleController.text.trim();
        existing.categoryId = _categoryId;
        existing.durationMinutes = _durationMinutes;
        existing.notes = notes.isEmpty ? null : notes;
        existing.behaviorId = _behaviorId;
        existing.isImportant = _isImportant;
        await notifier.updateTemplate(existing);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(categoryListProvider);

    // Stage 2's panes, staggered in exactly like task_detail_sheet.dart/
    // zone_form_screen.dart's own `staggeredPanes` — a plain list so the
    // entrance index is each pane's position in it, not hand-numbered at
    // each call site.
    final staggeredPanes = [
      TemplateCategoryPane(
        theme: theme,
        categories: categories,
        selectedId: _categoryId,
        onChanged: (id) => setState(() => _categoryId = id),
      ),
      // Right after Category, matching the task detail sheet's own
      // adjacency ("after category, add important").
      TemplateImportantPane(
        theme: theme,
        value: _isImportant,
        onChanged: (value) => setState(() => _isImportant = value),
      ),
      TemplateDurationPane(
        theme: theme,
        durationMinutes: _durationMinutes,
        onPick: _pickDuration,
        onClear: () => setState(() => _durationMinutes = null),
      ),
      // Tracked-behavior link, gated exactly as the task detail sheet
      // gates its own: with the flag off this whole subtree is
      // const-eliminated and the field is absent from the form entirely,
      // not merely disabled.
      if (FeatureFlags.trackedBehaviorEnabled)
        TemplateBehaviorPane(
          theme: theme,
          behaviors: ref.watch(trackedBehaviorListProvider),
          selectedId: _behaviorId,
          onChanged: (id) => setState(() => _behaviorId = id),
        ),
    ];

    return StepScaffold(
      theme: theme,
      modalTitle: _isEditing ? 'Edit template' : 'New template',
      titleAlignment: TextAlign.left,
      headerColor: theme.colorAccent,
      headerContent: null,
      onClose: () => Navigator.of(context).pop(),
      onBack: null,
      primaryLabel: _isNameStage
          ? 'Done'
          : (_isEditing ? 'Save template' : 'Create template'),
      onPrimaryPressed: _isNameStage
          ? _confirmNameStage
          : (_canSave ? _save : null),
      isPrimaryLoading: !_isNameStage && _isSaving,
      body: SingleChildScrollView(
        // Top reverted to a plain spacingLg — the fade now lives inside
        // StepScaffold's own header container, clipped to it.
        padding: EdgeInsets.fromLTRB(
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingXl * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and Description share one pane with the section title
            // outside it, matching task_detail_sheet.dart's own "Name and
            // Notes share one pane" convention exactly — both fields are
            // always in the tree, never rebuilt as a different instance,
            // so their Elements (and any keyboard/focus state) survive the
            // stage 1 -> 2 transition untouched. Description is visible
            // from stage 1 too, same as the task-creation flow's own
            // Notes field.
            AppPane(
              title: 'Name',
              child: Column(
                children: [
                  AppTextField(
                    controller: _titleController,
                    label: 'Template name',
                    autofocus: !_isEditing,
                    onSubmitted: (_) => _confirmNameStage(),
                  ),
                  SizedBox(height: theme.spacingSm),
                  AppTextField(
                    controller: _notesController,
                    label: 'Description',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            if (!_isNameStage) ...[
              SizedBox(height: theme.spacingLg),
              for (final (index, pane) in staggeredPanes.indexed) ...[
                AppStaggeredEntrance(index: index, child: pane),
                SizedBox(height: theme.spacingLg),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
