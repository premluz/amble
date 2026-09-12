import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_subtle_icon_button.dart';
import 'edit_mode_provider.dart';
import 'selected_date_provider.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayAbbreviations = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// This week's Sunday, for whichever week [date] falls in — the grid
/// below always renders a full Sun-Sat row, never a partial week.
DateTime _startOfWeek(DateTime date) {
  final d = _dateOnly(date);
  // DateTime.weekday is 1 (Monday) - 7 (Sunday); the grid's own leading
  // column is Sunday, so this walks back to the most recent Sunday
  // (weekday 7 becomes a 0-day walk-back, matching `_weekdayAbbreviations`
  // starting on S).
  final daysSinceSunday = d.weekday % 7;
  return d.subtract(Duration(days: daysSinceSunday));
}

/// Replaces the bottom day-strip entirely — requested directly, with a
/// reference screenshot: the calendar (month name, week-of-dates grid,
/// sync placeholder, "jump to today" button, Edit Mode toggle) moves to
/// the TOP of the screen, shared by both the Task-view and Timeline
/// (Zone-view) tabs, in place of the old bottom-nav-adjacent day strip and
/// its own separate Edit Mode link.
///
/// Two rows: month name (tap to step the visible week back/forward — no
/// full month-picker popup, confirmed via AskUserQuestion as out of scope
/// for this pass) + the utility icons, then a fixed Sun-Sat week grid
/// (never an infinite horizontal scroll — confirmed via AskUserQuestion
/// as a genuine layout change from the old day-chip strip, not just a
/// relocation of it).
///
/// Icons are "very subtle outline" per direct reference, not the app's
/// existing filled-accent `AppIconButton` (that circle reads as a primary
/// action; these three are secondary utility controls) — `AppSubtleIconButton`
/// (`core/widgets/`), promoted out of this file 2026-09-12 so the Tracked
/// tab's own view-cycle switcher can use the identical style.
///
/// **While Edit Mode is active**, this widget collapses to JUST the Edit
/// Mode toggle itself (now showing a close/X glyph), top-right, in the
/// same position — reported directly as a real gap: the whole header used
/// to hide outright once Edit Mode turned on, taking its own only exit
/// control down with it.
class AppCalendarHeader extends ConsumerWidget {
  const AppCalendarHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final editModeEnabled = ref.watch(editModeEnabledProvider);

    // **2026-09-12 — reported directly as a real gap.** The full calendar
    // (month stepper, week grid, sync) still hides entirely while Edit
    // Mode is active (see `timeline_screen.dart`'s own `if`, unchanged),
    // but the Edit Mode toggle itself — the only way to turn it back off
    // from this header — must stay reachable in the same top-right spot
    // rather than disappearing along with everything else. So this
    // widget renders only the close button, alone, in that case, instead
    // of vanishing outright.
    if (editModeEnabled) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacingScreenPadding,
          theme.spacingSm,
          theme.spacingScreenPadding,
          theme.spacingSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_EditModeIconButton(theme: theme)],
        ),
      );
    }

    final selectedDate = ref.watch(selectedDateProvider);
    final today = _dateOnly(DateTime.now());
    final weekStart = _startOfWeek(selectedDate);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        theme.spacingSm,
        theme.spacingScreenPadding,
        theme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MonthStepper(theme: theme, monthOf: selectedDate),
              ),
              _TodayButton(theme: theme, today: today),
              SizedBox(width: theme.spacingSm),
              // Sync — placeholder only per direct confirmation (device-
              // calendar pull/push is a separate future task); tapping
              // currently does nothing.
              const AppSubtleIconButton(
                icon: Icons.sync_rounded,
                tooltip: 'Sync',
                onTap: null,
              ),
              SizedBox(width: theme.spacingSm),
              // Edit Mode's OWN entry point, restyled — was a text link
              // ("Edit"/"Done"), now this pen icon, confirmed directly
              // ("use edit icon (pen)"). This REVERSES a locked-in
              // CONSTITUTION.md design principle (a text link "so it
              // reads as a mode switch, not an action") on direct
              // instruction — see docs/DECISIONS.md for the reversal.
              _EditModeIconButton(theme: theme),
            ],
          ),
          SizedBox(height: theme.spacingSm),
          Row(
            children: [
              for (final label in _weekdayAbbreviations)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textCaption.copyWith(
                        color: theme.colorTextTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacingXs),
          // Horizontal swipe steps the visible week back/forward by 7
          // days — the bidirectional counterpart to the month-name tap's
          // forward-only shortcut above, and the closest equivalent to the
          // old day-strip's own scroll gesture now that the grid itself is
          // fixed-width rather than scrollable.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity == 0) return;
              final notifier = ref.read(selectedDateProvider.notifier);
              notifier.goTo(
                selectedDate.add(Duration(days: velocity < 0 ? 7 : -7)),
              );
            },
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _WeekDayCell(
                      theme: theme,
                      date: weekStart.add(Duration(days: i)),
                      isToday: _isSameDay(
                        weekStart.add(Duration(days: i)),
                        today,
                      ),
                      isSelected: _isSameDay(
                        weekStart.add(Duration(days: i)),
                        selectedDate,
                      ),
                      onTap: () => ref
                          .read(selectedDateProvider.notifier)
                          .goTo(weekStart.add(Duration(days: i))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The month name + chevron. Tapping steps the visible week forward by 7
/// days — confirmed via AskUserQuestion as the intended scope ("simple:
/// tap to cycle to next/prev week"), not a full month-grid picker popup.
/// A horizontal swipe on the week grid below (see [AppCalendarHeader])
/// covers the backward direction, so this tap is a one-way shortcut
/// alongside that gesture rather than the only way to move the week.
class _MonthStepper extends ConsumerWidget {
  const _MonthStepper({required this.theme, required this.monthOf});

  final AmbleTheme theme;
  final DateTime monthOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedDateProvider.notifier);
    return AppPressFeedback(
      onTap: () => notifier.goTo(monthOf.add(const Duration(days: 7))),
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingXs,
          vertical: theme.spacingXs,
        ),
        // No `mainAxisSize: min` — this sits in a fixed-width `Expanded`
        // slot alongside 3 utility icon buttons (see AppCalendarHeader),
        // and `min` sizing to unbounded content overflowed the row on a
        // real device width once those buttons' own space was accounted
        // for. `textTitle` (20px), not `textHeadline` (32px, meant for a
        // full page's own title) — a headline-sized month name never fit
        // beside the 3 buttons on any width this was tested at.
        child: Row(
          children: [
            Flexible(
              child: Text(
                _monthNames[monthOf.month - 1],
                style: theme.textTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: theme.spacingXs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorTextPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Jump to today" — always shows TODAY's own day-of-month (not a fixed
/// "12"; confirmed directly the reference screenshot's literal "12" was
/// just whatever day it was rendered on). Tapping navigates the selected
/// date back to today, regardless of which day is currently viewed.
class _TodayButton extends ConsumerWidget {
  const _TodayButton({required this.theme, required this.today});

  final AmbleTheme theme;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSubtleIconButton(
      tooltip: 'Today',
      onTap: () => ref.read(selectedDateProvider.notifier).goToToday(),
      child: Text(
        '${today.day}',
        style: theme.textCaption.copyWith(
          color: theme.colorTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditModeIconButton extends ConsumerWidget {
  const _EditModeIconButton({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(editModeEnabledProvider);
    return AppSubtleIconButton(
      // Reported directly: while Edit Mode is active, the SAME control
      // that opened it becomes its close button — a close (X) glyph, not
      // the pen icon still sitting there with no visible way to exit —
      // styled identically to the other top-right icons (no separate
      // control, no different shape).
      icon: enabled ? Icons.close_rounded : Icons.edit_outlined,
      tooltip: enabled ? 'Done' : 'Edit',
      // Same state the two-finger long-press gesture toggles — see
      // edit_mode_provider.dart's own "two entry points, converging on
      // the same state" contract, unchanged by this restyle.
      onTap: () => ref.read(editModeEnabledProvider.notifier).toggle(),
      // Accent-colored while active, so the mode still has a persistent
      // visual signal now that it's an icon rather than literal "Done"
      // text — the wiggle animation on the tasks themselves is the other
      // half of that signal, per CONSTITUTION.md's Edit Mode section.
      iconColor: enabled ? theme.colorAccent : null,
      borderColor: enabled ? theme.colorAccent : null,
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.theme,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Same "background marks selection, dot marks today" split DayStrip's
    // own day chip used — kept for continuity even though the surrounding
    // layout (fixed week grid vs. scrolling strip) changed.
    final background = isSelected
        ? theme.colorSurfaceField
        : Colors.transparent;

    return AppPressFeedback(
      onTap: onTap,
      shape: BoxShape.circle,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingXs / 2),
        child: Container(
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: theme.textBody.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              SizedBox(height: theme.spacingXs / 2),
              SizedBox(
                height: theme.spacingXs,
                child: isToday
                    ? Center(
                        child: Container(
                          width: theme.spacingXs,
                          height: theme.spacingXs,
                          decoration: BoxDecoration(
                            color: theme.colorAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
