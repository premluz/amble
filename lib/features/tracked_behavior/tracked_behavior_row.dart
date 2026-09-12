import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/task.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';
import '../../shared/providers/task_providers.dart';
import 'behavior_completion.dart';
import 'tracked_behavior_form.dart' show unitLabelFor;

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// One behavior card — title, its target read back in words, and a
/// completion-history visualization matching [viewMode]: a Mon-Sun week
/// row, a wrapping grid of the current month's days, or a GitHub-heatmap-
/// style grid of the trailing 6 months. Requested directly, from a
/// mockup: "let us build these views on the tracked section... this is
/// replacing the current cards... in the same way like in timeline we
/// have view switcher, in the same positions there will be view switcher
/// for each of these here, weekly, monthly, and six monthly."
///
/// Public so a widget test can target it directly.
class TrackedBehaviorRow extends ConsumerWidget {
  const TrackedBehaviorRow({
    super.key,
    required this.theme,
    required this.behavior,
    required this.viewMode,
    required this.onTap,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final TrackedBehaviorViewMode viewMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    final today = DateTime.now();

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusXl),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        behavior.title,
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: theme.spacingXs),
                      Text(
                        describeBehaviorTarget(behavior),
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorTextSecondary,
                ),
              ],
            ),
            SizedBox(height: theme.spacingMd),
            switch (viewMode) {
              TrackedBehaviorViewMode.weekly => _WeeklyRow(
                theme: theme,
                behavior: behavior,
                tasks: tasks,
                today: today,
              ),
              TrackedBehaviorViewMode.monthly => _MonthlyGrid(
                theme: theme,
                behavior: behavior,
                tasks: tasks,
                today: today,
              ),
              TrackedBehaviorViewMode.sixMonthly => _SixMonthlyHeatmap(
                theme: theme,
                behavior: behavior,
                tasks: tasks,
                today: today,
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// One day cell shared by all three views — a small rounded square,
/// filled solid accent when [completed], accent-outlined (never both)
/// when [isToday], plain otherwise. Sized via [size] so the same widget
/// serves the weekly row's larger cells and the six-month heatmap's much
/// smaller ones.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.theme,
    required this.completed,
    required this.isToday,
    required this.size,
    this.label,
  });

  final AmbleTheme theme;
  final bool completed;
  final bool isToday;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: completed ? theme.colorAccent : theme.colorSurfaceField,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: isToday
            ? Border.all(
                color: theme.colorAccent,
                width: theme.borderWidthHairline * 1.5,
              )
            : null,
      ),
      child: label == null
          ? null
          : Text(
              label!,
              style: theme.textCaption.copyWith(
                color: completed
                    ? theme.colorSurfacePrimary
                    : theme.colorTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// The current Mon-Sun week — 7 cells, weekday initials underneath (M T W
/// T F S S), matching the mockup's "W T F S" row generalized to the full
/// week.
class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final todayDay = DateTime(today.year, today.month, today.day);
    // Monday-start week — matches _weekdayInitials' own M-first order and
    // every other weekday strip in this codebase (day_strip.dart).
    final monday = todayDay.subtract(Duration(days: todayDay.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: monday,
      end: sunday,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Column(
            children: [
              _DayCell(
                theme: theme,
                completed: isDayCompleted(
                  completedDays,
                  monday.add(Duration(days: i)),
                ),
                isToday: isToday(monday.add(Duration(days: i)), todayDay),
                size: theme.spacingXl,
              ),
              SizedBox(height: theme.spacingXs),
              Text(
                _weekdayInitials[i],
                style: theme.textCaption.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A plain wrapping grid of the current month's numbered day cells — no
/// weekday-column alignment, confirmed directly as simpler than a real
/// calendar grid: days just wrap left-to-right, top-to-bottom in
/// declaration order (1, 2, 3, ...).
class _MonthlyGrid extends StatelessWidget {
  const _MonthlyGrid({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final todayDay = DateTime(today.year, today.month, today.day);
    final firstOfMonth = DateTime(today.year, today.month);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final lastOfMonth = DateTime(today.year, today.month, daysInMonth);
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: firstOfMonth,
      end: lastOfMonth,
    );

    return Wrap(
      spacing: theme.spacingXs,
      runSpacing: theme.spacingXs,
      children: [
        for (var d = 1; d <= daysInMonth; d++)
          _DayCell(
            theme: theme,
            completed: isDayCompleted(
              completedDays,
              DateTime(today.year, today.month, d),
            ),
            isToday: isToday(DateTime(today.year, today.month, d), todayDay),
            size: theme.spacingXl,
            label: '$d',
          ),
      ],
    );
  }
}

const _sixMonthlyCellSize = 12.0;
const _sixMonthlyDayCount = 183; // Trailing ~6 months.

/// A GitHub-heatmap-style grid spanning the trailing 6 months — small day
/// squares wrapping into rows (confirmed directly, over a single
/// horizontally-scrollable row), with month names as loose labels above
/// roughly where each month's squares begin. Requested directly: "same as
/// day and week grid of squares that don't distinguish when month ends
/// when new starts" — so the squares themselves flow continuously; only
/// the label row above marks month boundaries.
class _SixMonthlyHeatmap extends StatelessWidget {
  const _SixMonthlyHeatmap({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;

  static const _monthAbbreviations = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final todayDay = DateTime(today.year, today.month, today.day);
    final start = todayDay.subtract(
      const Duration(days: _sixMonthlyDayCount - 1),
    );
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: start,
      end: todayDay,
    );
    final days = [
      for (var i = 0; i < _sixMonthlyDayCount; i++)
        start.add(Duration(days: i)),
    ];

    // Month labels: one per calendar month actually spanned, positioned
    // over the index of that month's FIRST day in the flattened sequence
    // — a loose approximation (proportional spacing via Expanded/Spacer
    // segments) rather than pixel-exact alignment with the grid below,
    // since the grid itself wraps at a fixed column count unrelated to
    // month boundaries.
    final monthStarts = <String>[];
    var lastMonth = -1;
    for (final day in days) {
      if (day.month != lastMonth) {
        monthStarts.add(_monthAbbreviations[day.month - 1]);
        lastMonth = day.month;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in monthStarts) ...[
              Expanded(
                child: Text(
                  label,
                  style: theme.textCaption.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: theme.spacingXs),
        Wrap(
          spacing: theme.spacingXs / 2,
          runSpacing: theme.spacingXs / 2,
          children: [
            for (final day in days)
              _DayCell(
                theme: theme,
                completed: isDayCompleted(completedDays, day),
                isToday: isToday(day, todayDay),
                size: _sixMonthlyCellSize,
              ),
          ],
        ),
      ],
    );
  }
}

/// One line describing a behavior's target type, amount, and frequency —
/// e.g. "60 min · 3x a week", or "Did it · 5x a week" for a binary
/// behavior, which has no amount by definition.
///
/// A top-level function, not a row method, so a test can exercise the
/// wording directly without mounting a widget — the same shape
/// `_zoneSummary`/`_behaviorSummary` already use in `settings_screen.dart`.
String describeBehaviorTarget(TrackedBehavior behavior) {
  final frequency = '${behavior.timesPerWeek}x a week';
  if (behavior.isBinary) return 'Did it · $frequency';

  final amount = behavior.targetAmount;
  // Defensive: the model's constructor asserts a non-binary behavior has a
  // target, but an assert is debug-only, so this must not render "null" in
  // a release build if a malformed row ever reaches here.
  if (amount == null) return frequency;

  final minimum = behavior.minimumAmount;
  final unit = unitLabelFor(
    behavior.targetType,
    customUnitName: behavior.customUnitName,
  );
  final target = '${_formatAmount(amount)} $unit';
  if (minimum == null) return '$target · $frequency';
  return '$target (min ${_formatAmount(minimum)}) · $frequency';
}

/// Renders an amount without a trailing ".0" — a 60-minute target reads
/// "60 min", not "60.0 min".
String _formatAmount(num amount) {
  if (amount is int) return amount.toString();
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toString();
}
