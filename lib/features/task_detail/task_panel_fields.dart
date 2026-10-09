import 'package:flutter/material.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_field_row.dart';
import '../../core/widgets/app_text_field.dart';
import 'task_panel_detail_rows.dart';
import 'task_panel_labels.dart';
import 'task_sheet_fields.dart';
import 'task_sheet_form.dart';
import 'task_sheet_pickers.dart';

/// The task form in the wide layout's side panel: the same settings as
/// [TaskSheetFields], one per line with an icon (after Notion Calendar's
/// event panel) instead of the phone's wrapped chips. Each value opens its
/// picker beside itself, because the panel scopes pickers as popovers.
class TaskPanelFields extends StatelessWidget {
  const TaskPanelFields({
    super.key,
    required this.form,
    this.showPreset = false,
    this.autofocusName = false,
    this.titlePlaceholder = 'Add title',
    this.onNameFocusChanged,
  });

  final TaskSheetForm form;
  final bool showPreset;
  final bool autofocusName;
  final String titlePlaceholder;
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
            label: titlePlaceholder,
            variant: AppTextFieldVariant.bare,
            autofocus: autofocusName,
            onFocusChanged: onNameFocusChanged,
          ),
          SizedBox(height: theme.spacingSm),
          ..._scheduleRows(context),
          TaskPanelDetailRows(form: form),
          if (form.showFutureInstancesChoice) ...[
            SizedBox(height: theme.spacingSm),
            TaskFutureInstancesRow(theme: theme, form: form),
          ],
        ],
      ),
    );
  }

  List<Widget> _scheduleRows(BuildContext context) => [
    if (showPreset)
      AppFieldRow.single(
        icon: Icons.bookmark_border_rounded,
        label: 'Preset',
        hasValue: form.templateId != null,
        onTap: form.pickPreset,
      ),
    AppFieldRow(icon: Icons.schedule_rounded, children: _time(context)),
    AppFieldRow.single(
      icon: Icons.calendar_today_rounded,
      label: taskDateLabel(context, form.date),
      onTap: form.pickDate,
    ),
    AppFieldRow.single(
      icon: Icons.repeat_rounded,
      label: taskRepeatLabel(form),
      hasValue: form.repeats,
      onTap: form.pickRepeat,
    ),
  ];

  /// Start → end, then the length in the quiet tone; the end and the
  /// length both open the length picker.
  List<Widget> _time(BuildContext context) {
    final time = form.time;
    final minutes = form.durationMinutes;
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return [
      AppFieldValue(
        label: time == null ? 'Time' : timelineClock(context, time),
        hasValue: time != null,
        onTap: form.pickTime,
      ),
      if (time != null && minutes != null) ...[
        Icon(
          Icons.arrow_forward_rounded,
          size: theme.spacingMd,
          color: theme.colorTextSecondary,
        ),
        AppFieldValue(
          label: timelineClock(context, taskEndTime(time, minutes)),
          onTap: form.pickDuration,
        ),
      ],
      AppFieldValue(
        label: minutes == null ? 'Duration' : '${minutes}m',
        hasValue: false,
        onTap: form.pickDuration,
      ),
    ];
  }
}
