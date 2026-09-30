import 'package:flutter/material.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_value_chip.dart';
import '../../shared/models/category.dart';
import 'task_sheet_form.dart';
import 'task_sheet_pickers.dart';

/// The compact task sheet's content: the name, then its settings as chips
/// (each opening its own picker), and — when a repeating task's start or
/// length changed — whether that reaches the rest of the series. Shared by
/// the Timeline's in-place sheet and [showTaskSheet]. Adds no side padding;
/// the host places it.
class TaskSheetFields extends StatelessWidget {
  const TaskSheetFields({
    super.key,
    required this.form,
    this.showPreset = false,
    this.autofocusName = false,
    this.onNameFocusChanged,
  });

  final TaskSheetForm form;

  /// Presets fill a new task; editing one has no use for them.
  final bool showPreset;
  final bool autofocusName;
  final ValueChanged<bool>? onNameFocusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: form.title,
            label: 'Add title',
            variant: AppTextFieldVariant.bare,
            autofocus: autofocusName,
            onFocusChanged: onNameFocusChanged,
          ),
          SizedBox(height: theme.spacingMd),
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              if (showPreset)
                AppValueChip(
                  label: 'Preset',
                  hasValue: form.templateId != null,
                  onTap: () => form.pickPreset(context),
                ),
              AppValueChip(
                label: _dateLabel(context),
                hasValue: true,
                onTap: () => form.pickDate(context),
              ),
              AppValueChip(
                label: form.time == null
                    ? 'Time'
                    : timelineClock(context, form.time!),
                hasValue: form.time != null,
                onTap: () => form.pickTime(context),
              ),
              AppValueChip(
                label: form.durationMinutes == null
                    ? 'Duration'
                    : '${form.durationMinutes}m',
                hasValue: form.durationMinutes != null,
                onTap: () => form.pickDuration(context),
              ),
            ],
          ),
          SizedBox(height: theme.spacingSm),
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: _toggles(context),
          ),
          if (form.showFutureInstancesChoice) ...[
            SizedBox(height: theme.spacingMd),
            _FutureInstancesRow(theme: theme, form: form),
          ],
        ],
      ),
    );
  }

  List<Widget> _toggles(BuildContext context) => [
    AppValueChip(
      label: '',
      icon: Icons.star_rounded,
      iconOnly: true,
      hasValue: form.isImportant,
      onTap: () => form.isImportant = !form.isImportant,
    ),
    AppValueChip(
      label: '#',
      iconOnly: true,
      hasValue: form.categoryId != BuiltInCategoryIds.general,
      onTap: () => form.pickLabel(context),
    ),
    AppValueChip(
      label: '',
      icon: Icons.fingerprint_rounded,
      iconOnly: true,
      hasValue: form.behaviorId != null,
      onTap: () => form.pickBehavior(context),
    ),
    AppValueChip(
      label: '',
      icon: form.notificationsEnabled
          ? Icons.notifications_rounded
          : Icons.notifications_off_rounded,
      iconOnly: true,
      hasValue: form.notificationsEnabled,
      onTap: () => form.notificationsEnabled = !form.notificationsEnabled,
    ),
    AppValueChip(
      label: '',
      icon: Icons.repeat_rounded,
      iconOnly: true,
      hasValue: form.repeats,
      onTap: () => form.pickRepeat(context),
    ),
    AppValueChip(
      label: '',
      icon: Icons.notes_rounded,
      iconOnly: true,
      hasValue: form.description.text.trim().isNotEmpty,
      onTap: () => form.editNote(context),
    ),
  ];

  String _dateLabel(BuildContext context) {
    final date = form.date;
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _FutureInstancesRow extends StatelessWidget {
  const _FutureInstancesRow({required this.theme, required this.form});

  final AmbleTheme theme;
  final TaskSheetForm form;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SheetTokens.inset(theme),
      borderRadius: BorderRadius.circular(theme.radiusTaskPill),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingMd,
        vertical: theme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Affect future instances',
              style: theme.textBody.copyWith(color: theme.colorTextPrimary),
            ),
          ),
          AppSwitch(
            value: form.affectFutureInstances,
            onChanged: (value) => form.affectFutureInstances = value,
          ),
        ],
      ),
    ),
  );
}
