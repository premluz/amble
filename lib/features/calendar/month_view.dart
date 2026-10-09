import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/component_tokens.dart';
import '../../shared/providers/calendar_grid_lines_setting.dart';
import '../timeline/selected_date_provider.dart';
import 'calendar_span.dart';
import 'month_day_cell.dart';
import '../../core/widgets/app_hairline.dart';

/// The wide layout's month: whole weeks covering the selected date's month,
/// Monday first, each day listing its tasks. Not spatial and without zones,
/// by request: a month is for seeing what's on, not when exactly.
class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final days = monthGridOf(selected);
    final rows = days.length ~/ DateTime.daysPerWeek;
    final line = ref.watch(calendarGridLinesSettingProvider)
        ? AppHairline.side(context, CalendarGridTokens.dayLineAlpha)
        : BorderSide.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MonthHeader(),
        for (var row = 0; row < rows; row++)
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(top: line)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < DateTime.daysPerWeek; col++)
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: col == 0 ? null : Border(left: line),
                        ),
                        child: _cell(
                          days[row * DateTime.daysPerWeek + col],
                          selected,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(DateTime day, DateTime selected) => ClipRect(
    child: MonthDayCell(day: day, inMonth: day.month == selected.month),
  );
}

/// The weekday names above the grid, Monday first.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Row(
      children: [
        for (final name in weekdayShortNames)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: theme.spacingXs),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textLabel.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
