import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_follow_through.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/task.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';
import '../../shared/providers/task_providers.dart';
import 'behavior_completion.dart';
import 'tracked_behavior_form.dart' show unitLabelFor;
import 'tracked_calendar_period.dart';

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

double _weeklyDaySpacing(double availableWidth, AmbleTheme theme) {
  final dayCount = _weekdayInitials.length;
  final gapCount = dayCount - 1;
  final unusedWidth = availableWidth - dayCount * theme.spacingXl;
  return unusedWidth <= 0 ? 0 : unusedWidth / gapCount;
}

/// One behavior card — title, its target read back in words, and a
/// completion-history visualization matching [viewMode]: a Mon-Sun week
/// row, a wrapping grid of the displayed month, or a GitHub-heatmap-style
/// grid of the displayed January-June or July-December half-year. Requested
/// directly, from a mockup: "let us build these views on the tracked
/// section... this is replacing the current cards... in the same way like
/// in timeline we have view switcher, in the same positions there will be
/// view switcher for each of these here, weekly, monthly, and six monthly."
///
/// Public so a widget test can target it directly.
class TrackedBehaviorRow extends ConsumerWidget {
  const TrackedBehaviorRow({
    super.key,
    required this.theme,
    required this.behavior,
    required this.viewMode,
    required this.periodDate,
    required this.showCalendarLabels,
    required this.onTap,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final TrackedBehaviorViewMode viewMode;
  final DateTime periodDate;
  final bool showCalendarLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    final today = DateTime.now();

    // The card trails the page as it slides in or out.
    return AppFollowThrough(
      child: AppPressFeedback(
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
              // Just the title now — requested directly: hide the unit/type
              // line underneath it (see `describeBehaviorTarget`'s own doc
              // comment for the line this replaces).
              Text(
                behavior.title,
                style: theme.textTaskTitle.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: theme.spacingMd),
              switch (viewMode) {
                TrackedBehaviorViewMode.weekly => _WeeklyRow(
                  theme: theme,
                  behavior: behavior,
                  tasks: tasks,
                  today: today,
                  periodDate: periodDate,
                  showCalendarLabels: showCalendarLabels,
                ),
                TrackedBehaviorViewMode.monthly => _MonthlyGrid(
                  theme: theme,
                  behavior: behavior,
                  tasks: tasks,
                  today: today,
                  periodDate: periodDate,
                  showCalendarLabels: showCalendarLabels,
                ),
                TrackedBehaviorViewMode.sixMonthly => _SixMonthlyHeatmap(
                  theme: theme,
                  behavior: behavior,
                  tasks: tasks,
                  today: today,
                  periodDate: periodDate,
                  showCalendarLabels: showCalendarLabels,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// One day cell shared by all three views. Completion uses the accent;
/// incomplete cells use quieter theme-scale surfaces and labels, with a
/// distinct current-day treatment in dark mode. Completion takes precedence;
/// today is not also accent-outlined. Sized via [size] so the same widget
/// serves the weekly row and six-month heatmap.
///
/// **2026-09-21 — circular, was a rounded square.** Requested directly:
/// tracked slots should be fully rounded across every view. `BoxShape
/// .circle` rather than a large `BorderRadius.circular`, since [size]
/// (and therefore this cell) is always a perfect square — a circle shape
/// stays exactly round at any size, where a fixed corner radius would
/// under-round the larger weekly cells.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.theme,
    required this.completed,
    required this.isToday,
    required this.size,
    this.label,
    this.weekdayLabel = false,
  });

  final AmbleTheme theme;
  final bool completed;
  final bool isToday;
  final double size;
  final String? label;
  final bool weekdayLabel;

  bool get _isDark =>
      theme.colorTextPrimary.computeLuminance() >
      theme.colorSurfaceBase.computeLuminance();

  Color get _fillColor {
    if (completed) return theme.colorAccent;
    if (!_isDark) return theme.colorSurfaceField;
    return isToday ? theme.colorSurfaceFieldActive : theme.colorSurfaceOverlay;
  }

  Color get _labelColor {
    if (completed) return theme.colorSurfacePrimary;
    if (isToday && _isDark) return theme.colorTextPrimary;
    if (isToday || weekdayLabel || _isDark) return theme.colorTextTertiary;
    return theme.colorTextSecondary;
  }

  TextStyle get _labelStyle =>
      isToday && _isDark ? theme.textLabel : theme.textCaption;

  @override
  Widget build(BuildContext context) {
    // Each dot trails its own card as the page slides, so the card's dots
    // follow through one after another.
    return AppFollowThrough(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _fillColor, shape: BoxShape.circle),
        child: label == null
            ? null
            : Text(label!, style: _labelStyle.copyWith(color: _labelColor)),
      ),
    );
  }
}

/// The selected Mon-Sun week — 7 cells, weekday initials underneath (M T W
/// T F S S), matching the mockup's "W T F S" row generalized to the full
/// week.
class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
    required this.periodDate,
    required this.showCalendarLabels,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;
  final DateTime periodDate;
  final bool showCalendarLabels;

  @override
  Widget build(BuildContext context) {
    final todayDay = DateTime(today.year, today.month, today.day);
    // Monday-start week — matches _weekdayInitials' own M-first order and
    // every other weekday strip in this codebase (day_strip.dart).
    final monday = TrackedCalendarPeriod.start(
      periodDate,
      TrackedBehaviorViewMode.weekly,
    );
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: monday,
      end: TrackedCalendarPeriod.end(
        periodDate,
        TrackedBehaviorViewMode.weekly,
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          // The weekday initial sits INSIDE the circle, exactly as the
          // monthly grid puts its day numbers inside theirs — requested
          // directly. It used to be a separate `Text` in a `Column`
          // below the cell, which made the two views read as different
          // components rather than the same one labelled differently.
          _DayCell(
            theme: theme,
            completed: isDayCompleted(
              completedDays,
              monday.add(Duration(days: i)),
            ),
            isToday: isToday(monday.add(Duration(days: i)), todayDay),
            size: theme.spacingXl,
            label: showCalendarLabels ? _weekdayInitials[i] : null,
            weekdayLabel: showCalendarLabels,
          ),
      ],
    );
  }
}

/// A plain wrapping grid of the selected month's numbered day cells — no
/// weekday-column alignment, confirmed directly as simpler than a real
/// calendar grid: days just wrap left-to-right, top-to-bottom in
/// declaration order (1, 2, 3, ...).
class _MonthlyGrid extends StatelessWidget {
  const _MonthlyGrid({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
    required this.periodDate,
    required this.showCalendarLabels,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;
  final DateTime periodDate;
  final bool showCalendarLabels;

  @override
  Widget build(BuildContext context) {
    final todayDay = DateTime(today.year, today.month, today.day);
    final firstOfMonth = TrackedCalendarPeriod.start(
      periodDate,
      TrackedBehaviorViewMode.monthly,
    );
    final lastOfMonth = TrackedCalendarPeriod.end(
      periodDate,
      TrackedBehaviorViewMode.monthly,
    );
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: firstOfMonth,
      end: lastOfMonth,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final daySpacing = _weeklyDaySpacing(constraints.maxWidth, theme);
        return Wrap(
          spacing: daySpacing,
          runSpacing: daySpacing,
          children: [
            for (var d = 1; d <= lastOfMonth.day; d++)
              _DayCell(
                theme: theme,
                completed: isDayCompleted(
                  completedDays,
                  DateTime(periodDate.year, periodDate.month, d),
                ),
                isToday: isToday(
                  DateTime(periodDate.year, periodDate.month, d),
                  todayDay,
                ),
                size: theme.spacingXl,
                label: showCalendarLabels ? '$d' : null,
              ),
          ],
        );
      },
    );
  }
}

const _sixMonthlyCellSize = 12.0;

/// A GitHub-heatmap-style grid spanning the selected Jan-Jun or Jul-Dec
/// half-year. Day squares wrap continuously into rows, with month names as
/// loose labels above roughly where each month's squares begin. Requested
/// directly: "same as day and week grid of squares that don't distinguish
/// when month ends when new starts" — only the label row marks month
/// boundaries.
class _SixMonthlyHeatmap extends StatelessWidget {
  const _SixMonthlyHeatmap({
    required this.theme,
    required this.behavior,
    required this.tasks,
    required this.today,
    required this.periodDate,
    required this.showCalendarLabels,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final List<Task> tasks;
  final DateTime today;
  final DateTime periodDate;
  final bool showCalendarLabels;

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
    final start = TrackedCalendarPeriod.start(
      periodDate,
      TrackedBehaviorViewMode.sixMonthly,
    );
    final end = TrackedCalendarPeriod.end(
      periodDate,
      TrackedBehaviorViewMode.sixMonthly,
    );
    final dayCount = end.difference(start).inDays + 1;
    final completedDays = completedDaysFor(
      behavior,
      tasks: tasks,
      start: start,
      end: end,
    );
    final days = [
      for (var i = 0; i < dayCount; i++) start.add(Duration(days: i)),
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
        if (showCalendarLabels) ...[
          Row(
            children: [
              for (final label in monthStarts) ...[
                Expanded(
                  child: Text(
                    label,
                    style: theme.textCaption.copyWith(
                      color: theme.colorTextTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacingXs),
        ],
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
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
        ),
      ],
    );
  }
}

/// One short line naming what KIND of behavior this is — its unit, e.g.
/// "Minutes"/"Times"/"Glasses", or "Did it" for a binary one, which has
/// no unit by definition.
///
/// **2026-09-21 — no longer rendered in [TrackedBehaviorRow].** Requested
/// directly: the row now shows only the title, with this unit/type line
/// hidden underneath it. Kept as a top-level function rather than
/// deleted — it is still exercised directly by
/// `tracked_behavior_list_screen_test.dart`'s own `describeBehaviorTarget`
/// group, and the wording may resurface elsewhere later (the create/edit
/// form already shows the unit its own way).
String describeBehaviorTarget(TrackedBehavior behavior) {
  if (behavior.isBinary) return 'Did it';

  final unit = unitLabelFor(
    behavior.targetType,
    customUnitName: behavior.customUnitName,
  );
  // Sentence case: the unit reads as a label on its own line here, not as
  // a suffix trailing an amount ("min" was only ever right after "60").
  if (unit.isEmpty) return '';
  return unit[0].toUpperCase() + unit.substring(1);
}
