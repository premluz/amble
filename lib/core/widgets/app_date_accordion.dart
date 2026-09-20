import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';
import 'app_sheet_handle.dart';

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

/// Full weekday names, Monday-first (matching [DateTime.weekday]'s own
/// 1-7 numbering) — for the date LABEL ("Wed 14 Sep"), distinct from
/// [_weekdayAbbreviations] (the single-letter S/M/T/W/T/F/S column
/// headers above the week grid, Sunday-first to match that grid's own
/// leading column).
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// This week's Sunday, for whichever week [date] falls in — the grid
/// always renders a full Sun-Sat row, never a partial week.
DateTime _startOfWeek(DateTime date) {
  final d = _dateOnly(date);
  final daysSinceSunday = d.weekday % 7;
  return d.subtract(Duration(days: daysSinceSunday));
}

/// The "current day" indicator — a month/date label with a chevron that
/// expands/collapses a Sun-Sat week-of-days strip, with swipe-to-change-
/// week built in. Extracted as a genuinely standalone, reusable component
/// (added to the Widgetbook gallery) rather than inline markup on one
/// screen — requested directly: "make it actually a component inside our
/// storybook... so we can easily reuse it."
///
/// **Collapsed by default, tap the chevron to reveal the week strip** —
/// requested directly against a nav-redesign screenshot: the week grid
/// used to always render; now it's an accordion, closed until asked for,
/// so the date row stays a single compact line most of the time. The
/// small grip bar under the date label ([AppSheetHandle]) is the visual
/// "this expands" affordance — purely decorative for now (no drag
/// gesture wired to it yet), matching the reference design's own note
/// that the handle isn't functional yet: "for now do on tap reveal/hide
/// days."
///
/// Genuinely reusable: this widget owns no app-specific provider — it
/// takes [selectedDate] and calls [onDateSelected], the same shape any
/// caller (the Timeline header, a future date-picker sheet, a Widgetbook
/// use case) can drive with its own state. It also owns its OWN
/// expanded/collapsed state internally (a pure UI concern, not something
/// a caller needs to lift), so a caller never has to wire a second
/// provider just to use it.
class AppDateAccordion extends StatefulWidget {
  const AppDateAccordion({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.initiallyExpanded = false,
  });

  /// The day currently shown as selected in the week strip — NOT
  /// necessarily today (see [AppDateAccordion] compared with a "jump to
  /// today" control, which a caller wires separately; this widget only
  /// renders and reports selection, it never assumes "today" is special
  /// beyond the small accent dot under that cell).
  final DateTime selectedDate;

  final ValueChanged<DateTime> onDateSelected;

  /// Whether the week strip starts open — defaults to false (collapsed),
  /// the "quiet by default" behaviour requested directly. Only read once,
  /// at construction — this is a normal, user-toggleable UI state after
  /// that, not a value a caller keeps re-driving.
  final bool initiallyExpanded;

  @override
  State<AppDateAccordion> createState() => _AppDateAccordionState();
}

class _AppDateAccordionState extends State<AppDateAccordion> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final today = _dateOnly(DateTime.now());
    final weekStart = _startOfWeek(widget.selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateLabelRow(
          theme: theme,
          monthOf: widget.selectedDate,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        SizedBox(height: theme.spacingXs),
        // Purely decorative for now (see class doc comment) — centered
        // under the label, same affordance a draggable sheet uses
        // elsewhere in the app, so "this row does something on
        // tap/drag" reads consistently across the app rather than this
        // being a one-off shape.
        Center(child: AppSheetHandle(theme: theme)),
        // AnimatedSize, not a bare conditional — an accordion that pops
        // open/shut with no transition reads as a layout glitch, not a
        // deliberate reveal. `curveStandard`/`motionNormal` are the same
        // easing/duration every other expand-in-place moment in the app
        // already uses, not a bespoke animation invented for this one
        // widget.
        AnimatedSize(
          duration: theme.motionNormal,
          curve: theme.curveStandard,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _WeekStrip(
                  theme: theme,
                  weekStart: weekStart,
                  today: today,
                  selectedDate: widget.selectedDate,
                  onDateSelected: widget.onDateSelected,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The month name + chevron. Tapping toggles the week strip open/shut —
/// requested directly: "with chevron that opens the currently always
/// visible days." Reversed from `AppCalendarHeader`'s own predecessor,
/// where this same tap stepped the visible week forward by 7 days — that
/// behaviour still exists (swipe on the week strip itself, see
/// `_WeekStrip`), it just isn't this row's job any more now that the row
/// has an expand/collapse job to do instead.
class _DateLabelRow extends StatelessWidget {
  const _DateLabelRow({
    required this.theme,
    required this.monthOf,
    required this.expanded,
    required this.onTap,
  });

  final AmbleTheme theme;
  final DateTime monthOf;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `Flexible`, not a bare `Text` — this row is reused in tighter
          // contexts than the full calendar header (e.g. the armed-task
          // edit bar), where `MainAxisSize.min` combined with an
          // unconstrained label caused a `RenderFlex` overflow instead of
          // shrinking to fit.
          Flexible(
            child: Text(
              // "Wed 14 Sep" — matches the reference design exactly:
              // weekday abbreviation, day-of-month, month abbreviation.
              '${_weekdayNames[monthOf.weekday - 1]} ${monthOf.day} '
              '${_monthNames[monthOf.month - 1].substring(0, 3)}',
              style: theme.textTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: theme.spacingXs),
          // Rotates to point up once expanded — the same "this chevron
          // shows which way it will fold" convention a disclosure
          // triangle always uses, so the row communicates its own state
          // without needing a second label ("Show days"/"Hide days").
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: theme.motionNormal,
            curve: theme.curveStandard,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The weekday-letter row + the Sun-Sat day grid, with swipe-to-change-
/// week — split out of the old `AppCalendarHeader` unchanged in
/// substance, just re-hosted as this widget's own expandable content.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.theme,
    required this.weekStart,
    required this.today,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final AmbleTheme theme;
  final DateTime weekStart;
  final DateTime today;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        // days — unchanged from `AppCalendarHeader`'s own original
        // gesture, just living here now.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity == 0) return;
            onDateSelected(
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
                    onTap: () =>
                        onDateSelected(weekStart.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
        ),
      ],
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
    // Same "background marks selection, dot marks today" split
    // `AppCalendarHeader`'s own predecessor used — kept unchanged for
    // continuity even as the surrounding shell (accordion vs. always-on)
    // changes around it.
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
                style: theme.textCaption.copyWith(
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
