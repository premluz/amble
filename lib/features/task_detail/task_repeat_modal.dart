import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';

/// The repeat state returned by [TaskRepeatModal]. The selected weekdays are
/// kept in the same 1–7 Monday-first convention as [RecurrenceRule].
class TaskRepeatSelection {
  const TaskRepeatSelection({
    required this.enabled,
    required this.selectedDays,
  });

  final bool enabled;
  final Set<int> selectedDays;

  RecurrenceRule? get recurrenceRule {
    if (!enabled) return null;
    final days = selectedDays.isEmpty ? {DateTime.monday} : selectedDays;
    if (days.length == 7) {
      return RecurrenceRule(frequency: RecurrenceFrequency.daily);
    }
    return RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      daysOfWeek: days.toList()..sort(),
    );
  }
}

/// The compact repeat picker used by quick add. It keeps the full task
/// flow's switch and weekday choices, but presents them as one focused sheet.
class TaskRepeatModal extends StatefulWidget {
  const TaskRepeatModal({
    super.key,
    required this.enabled,
    required this.selectedDays,
  });

  final bool enabled;
  final Set<int> selectedDays;

  static Future<TaskRepeatSelection?> show({
    required BuildContext context,
    required bool enabled,
    required Set<int> selectedDays,
  }) {
    return AppSheet.show<TaskRepeatSelection>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) =>
          TaskRepeatModal(enabled: enabled, selectedDays: selectedDays),
    );
  }

  @override
  State<TaskRepeatModal> createState() => _TaskRepeatModalState();
}

class _TaskRepeatModalState extends State<TaskRepeatModal> {
  late bool _enabled;
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _selectedDays = {...widget.selectedDays};
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      TaskRepeatSelection(enabled: _enabled, selectedDays: {..._selectedDays}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          theme: theme,
          title: 'Repeat',
          onClose: () => Navigator.of(context).pop(),
          trailing: AppButton(
            label: 'Done',
            size: AppButtonSize.md,
            shape: AppButtonShape.pill,
            onPressed: _finish,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Repeat', style: theme.textBody),
            AppSwitch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ],
        ),
        if (_enabled) ...[
          SizedBox(height: theme.spacingSm),
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                AppSelectableChip(
                  label: _weekdayAbbreviations[day - 1],
                  selected: _selectedDays.contains(day),
                  onTap: () => _toggleDay(day),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

const _weekdayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
