import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_selectable_chip.dart';
import 'app_switch.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';

/// A "Repeat" switch above a row of seven weekday chips.
///
/// Promoted to a shared widget on its THIRD caller, exactly as
/// docs/DECISIONS.md's own entry on the duplication said to: "two
/// duplicates is an accepted trade, three would cross into 'should have
/// been promoted'." The first two copies are `task_detail_sheet.dart`'s
/// private `_RecurrencePanel` and `zone_form_screen.dart`'s private
/// `_ZoneRecurrencePanel`; the third would have been the zone grid's own
/// new-zone sheet, which is what triggered this extraction.
///
/// Fully controlled — it owns no state of its own, so a caller keeps
/// whatever representation it already has and this only renders it.
class WeekdayRepeatPanel extends StatelessWidget {
  const WeekdayRepeatPanel({
    super.key,
    required this.theme,
    required this.repeats,
    required this.selectedDays,
    required this.onRepeatsChanged,
    required this.onDayToggled,
  });

  final AmbleTheme theme;
  final bool repeats;

  /// `DateTime.monday`..`DateTime.sunday` (1-7), matching the values
  /// [RecurrenceRule.daysOfWeek] itself stores.
  final Set<int> selectedDays;

  final ValueChanged<bool> onRepeatsChanged;
  final ValueChanged<int> onDayToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacingSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repeat',
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
              AppSwitch(value: repeats, onChanged: onRepeatsChanged),
            ],
          ),
        ),
        if (repeats) ...[
          SizedBox(height: theme.spacingSm),
          Row(
            children: [
              for (
                var day = DateTime.monday;
                day <= DateTime.sunday;
                day++
              ) ...[
                if (day > DateTime.monday) SizedBox(width: theme.spacingXs),
                Expanded(
                  child: AppSelectableChip(
                    label: weekdayAbbreviations[day - 1],
                    selected: selectedDays.contains(day),
                    onTap: () => onDayToggled(day),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

const weekdayAbbreviations = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// All 7 days maps to daily; any smaller selection maps to weekly with
/// that exact `daysOfWeek` set.
RecurrenceRule recurrenceRuleFromSelectedDays(Set<int> selectedDays) {
  if (selectedDays.length == 7) {
    return RecurrenceRule(frequency: RecurrenceFrequency.daily);
  }
  return RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    daysOfWeek: selectedDays.toList()..sort(),
  );
}

/// The inverse, for pre-filling an existing rule's panel. Daily has no
/// `daysOfWeek` (it means every day by definition), so it maps back to
/// all 7.
Set<int> selectedDaysFromRecurrenceRule(RecurrenceRule rule) {
  if (rule.frequency == RecurrenceFrequency.daily) {
    return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day};
  }
  return rule.daysOfWeek!.toSet();
}
