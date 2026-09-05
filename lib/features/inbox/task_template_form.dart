import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
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
/// Presented via [AppSheet] rather than the task detail screen's
/// near-full-screen modal, matching `showTrackedBehaviorForm`'s own
/// precedent and its recorded reasoning (docs/DECISIONS.md): that
/// full-screen pattern exists for the detail screen's colored edge-to-edge
/// header, live schedule preview, and wheel controls — none of which a
/// template has, since a template carries no time at all. Four short
/// fields don't justify a full-screen takeover.
///
/// All writes go through `taskTemplateListProvider`; this UI never touches
/// the repository or Hive directly.
Future<void> showTaskTemplateForm(
  BuildContext context, {
  TaskTemplate? template,
}) {
  return AppSheet.show(
    context: context,
    size: AppSheetSize.half,
    builder: (context) => _TaskTemplateForm(template: template),
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

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _notesController = TextEditingController(text: template?.notes ?? '');
    // General for a fresh template — the same neutral default the task
    // detail sheet's own create path uses, rather than silently picking
    // one of the real categories.
    _categoryId = template?.categoryId ?? BuiltInCategoryIds.general;
    _durationMinutes = template?.durationMinutes;
    _behaviorId = template?.behaviorId;
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
  bool get _canSave => _titleController.text.trim().isNotEmpty;

  Future<void> _pickDuration() async {
    final minutes = await TaskDurationModal.show(
      context: context,
      initialMinutes: _durationMinutes,
    );
    if (minutes == null) return;
    setState(() => _durationMinutes = minutes);
  }

  Future<void> _save() async {
    if (!_canSave) return;
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
      );
    } else {
      existing.title = _titleController.text.trim();
      existing.categoryId = _categoryId;
      existing.durationMinutes = _durationMinutes;
      existing.notes = notes.isEmpty ? null : notes;
      existing.behaviorId = _behaviorId;
      await notifier.updateTemplate(existing);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(categoryListProvider);
    final isEdit = widget.template != null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? 'Edit template' : 'New template',
            style: theme.textTitle.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: theme.spacingMd),

          AppTextField(
            controller: _titleController,
            label: 'Template name',
            autofocus: !isEdit,
          ),
          SizedBox(height: theme.spacingSm),
          AppTextField(
            controller: _notesController,
            label: 'Description',
            maxLines: 3,
          ),
          SizedBox(height: theme.spacingLg),

          TemplateCategoryPane(
            theme: theme,
            categories: categories,
            selectedId: _categoryId,
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          SizedBox(height: theme.spacingLg),

          TemplateDurationPane(
            theme: theme,
            durationMinutes: _durationMinutes,
            onPick: _pickDuration,
            onClear: () => setState(() => _durationMinutes = null),
          ),
          SizedBox(height: theme.spacingLg),

          // Tracked-behavior link, gated exactly as the task detail sheet
          // gates its own: with the flag off this whole subtree is
          // const-eliminated and the field is absent from the form
          // entirely, not merely disabled.
          if (FeatureFlags.trackedBehaviorEnabled) ...[
            SizedBox(height: theme.spacingLg),
            TemplateBehaviorPane(
              theme: theme,
              behaviors: ref.watch(trackedBehaviorListProvider),
              selectedId: _behaviorId,
              onChanged: (id) => setState(() => _behaviorId = id),
            ),
          ],

          SizedBox(height: theme.spacingLg),
          // Only the button reacts per keystroke, rather than rebuilding
          // the whole form on every character — same ListenableBuilder
          // pattern `_DetailsStepScaffold` already uses for its own
          // title-gated primary button.
          ListenableBuilder(
            listenable: _titleController,
            builder: (context, _) => SizedBox(
              width: double.infinity,
              child: AppButton(
                label: isEdit ? 'Save template' : 'Create template',
                onPressed: _canSave ? _save : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
