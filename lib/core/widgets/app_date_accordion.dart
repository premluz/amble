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

/// **2026-09-21 — Monday-first, was Sunday-first.** Requested directly
/// against a mock: "the order should start from Monday, and the first day
/// should be Monday." Brings this strip in line with the rest of the app,
/// which was already Monday-first everywhere else — `DateTime.weekday`'s
/// own 1-7 numbering, the recurrence generators' `_startOfWeek`, and the
/// task detail sheet's own `MON..SUN` repeat-day picker.
const _weekdayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Full weekday names, Monday-first (matching [DateTime.weekday]'s own
/// 1-7 numbering) — for the date LABEL ("Wed 14 Sep"), distinct from
/// [_weekdayAbbreviations] (the single-letter M/T/W/T/F/S/S column
/// headers above the week grid). Both are Monday-first as of 2026-09-21.
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// This week's Monday, for whichever week [date] falls in — the grid
/// always renders a full Mon-Sun row, never a partial week.
///
/// **2026-09-21 — Monday-first, was Sunday-first.** See
/// [_weekdayAbbreviations]. `DateTime.weekday` is already 1 (Monday) to 7
/// (Sunday), so subtracting `weekday - 1` lands on Monday directly —
/// matching `recurrence_generator.dart`'s own `_startOfWeek`, which has
/// always been Monday-first.
DateTime _startOfWeek(DateTime date) {
  final d = _dateOnly(date);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// The "current day" indicator — a month/date label with a chevron that
/// expands/collapses a Mon-Sun week-of-days strip, with swipe-to-change-
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
/// use case) can drive with its own state. Expanded/collapsed state is
/// UNCONTROLLED (owned internally, via [initiallyExpanded]) by default —
/// a caller never has to wire a second provider just to use it — but can
/// be lifted out via [expanded]/[onExpandedChanged] when a caller genuinely
/// needs to share it across more than one mount of this widget. See
/// `AppCalendarHeader`'s own use of [DateAccordionExpanded]
/// (`features/timeline/date_accordion_expanded_provider.dart`) for why:
/// reported directly, opening the week strip on the Timeline screen then
/// pushing into the merged Edit screen (a SEPARATE `AppDateAccordion`
/// mount, same widget type) landed back on collapsed, since each mount's
/// own internal `State` never talked to the other.
class AppDateAccordion extends StatefulWidget {
  const AppDateAccordion({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpandedChanged,
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
  /// at construction (as this widget's own internal state's initial
  /// value); has no effect at all when [expanded] is supplied (a
  /// controlled caller owns the initial value itself).
  final bool initiallyExpanded;

  /// Lifts expanded/collapsed state out to the caller — pass alongside
  /// [onExpandedChanged] (both null, the default, or both non-null; never
  /// just one) when more than one mount of this widget needs to share ONE
  /// state, e.g. via a Riverpod provider. Null (the default) keeps this
  /// widget fully self-contained, tracking its own `State` exactly as
  /// before.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<AppDateAccordion> createState() => _AppDateAccordionState();
}

class _AppDateAccordionState extends State<AppDateAccordion> {
  late bool _uncontrolledExpanded = widget.initiallyExpanded;

  bool get _expanded => widget.expanded ?? _uncontrolledExpanded;

  void _setExpanded(bool value) {
    final onExpandedChanged = widget.onExpandedChanged;
    if (onExpandedChanged != null) {
      onExpandedChanged(value);
    } else {
      setState(() => _uncontrolledExpanded = value);
    }
  }

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
          onTap: () => _setExpanded(!_expanded),
        ),
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
        SizedBox(height: theme.spacingXs),
        // **2026-09-20 — moved BELOW the week strip.** Reported directly:
        // this handle used to sit fixed between the label and the
        // strip, so opening the days never moved it at all — it just
        // stayed pinned under the label while the strip appeared below
        // it, reading as stuck rather than as part of the reveal.
        // Purely decorative for now (see class doc comment) — same
        // affordance a draggable sheet uses elsewhere in the app, so
        // "this row does something on tap/drag" reads consistently
        // across the app rather than this being a one-off shape.
        Center(child: AppSheetHandle(theme: theme)),
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

/// The weekday-letter row + the Mon-Sun day grid, with swipe-to-change-
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
        // `spacingMd`, was `spacingSm` — requested directly against a
        // side-by-side mock: "slightly larger space between the calendar
        // day with chevron and the days expanded."
        SizedBox(height: theme.spacingMd),
        // **The spread rule: first and last day flush, the rest evenly
        // between.** Requested directly against a side-by-side mock —
        // "both Monday is aligned with the left edge, and Sunday is
        // aligned with the right edge."
        //
        // Two shapes were tried and are both wrong, for opposite reasons,
        // so they are recorded here rather than rediscovered:
        //
        // 1. 7 fixed `sizeButtonMd` (40px) cells under `spaceBetween` —
        //    the BOXES reached the row's bounds, but each held a ~24px
        //    number centred inside it, so the visible digits floated ~8px
        //    inward. Measured on a 400px screen at the 16px inset: the
        //    first number painted at 23.75, the last ended at 376.25,
        //    against the 16..384 the boxes spanned.
        // 2. 7 equal `Expanded` columns, each centring its cell — an even
        //    division, but the outermost CENTRES sit half a column in
        //    from the edges by construction, which is exactly the inset
        //    the mock rejects.
        //
        // `spaceBetween` over naturally-sized children is the shape that
        // actually matches: `Row` gives the first child's leading edge
        // and the last child's trailing edge to the row's own bounds, and
        // distributes the slack between the remaining five.
        //
        // **2026-09-21 — there is no separate weekday-letter row any
        // more.** Each cell renders its own letter above its own number,
        // so one widget owns the whole column and can carry a single
        // tap target and selection fill spanning both — see
        // `_WeekDayCell`. A separate row made that structurally
        // impossible.
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
          // Opaque hit-testing needs a real, non-shrinking bounding box —
          // `Row` alone (no longer stretched by `Expanded` children) would
          // shrink to the sum of the 7 cells' own natural widths, leaving
          // the gaps BETWEEN them (most of this row's actual area) unable
          // to catch the swipe. `SizedBox(width: double.infinity)` forces
          // the full row width back, same as the old Expanded-per-cell
          // shape gave for free.
          child: SizedBox(
            width: double.infinity,
            // `spaceBetween` over naturally-sized cells, matching the
            // weekday-letter row above exactly — see its own comment for
            // the two shapes this replaced and why each was wrong. Each
            // cell sizes to its own NUMBER, so the first number's left
            // edge and the last number's right edge land on the row's
            // bounds; the selected day's fixed circle is drawn behind
            // that number without widening the cell (see `_WeekDayCell`),
            // so it may overhang the content edge on the outermost days —
            // confirmed as intended.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _WeekDayCell(
                    theme: theme,
                    label: _weekdayAbbreviations[i],
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.theme,
    required this.label,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final AmbleTheme theme;

  /// This day's single-letter column header ("M", "T", ...). Rendered by
  /// this cell rather than a separate row above it — see [build].
  final String label;

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

    // **2026-09-21 — the letter lives INSIDE this cell, and the fill is a
    // stadium covering both it and the number.** Requested directly
    // against a before/after mock: "the hit area should include day label
    // M T W etc., and active/hover should be [a stadium] including day
    // label."
    //
    // The letter used to be a sibling `Text` in its own `Row` above the
    // day-number row, which made a cell-sized hit target structurally
    // impossible — the two rows were separate widgets with separate
    // bounds, so a tap on "M" landed on nothing. Folding the letter in
    // means ONE widget owns the whole column: one tap target, one press
    // ripple, one selection fill.
    return AppPressFeedback(
      onTap: onTap,
      // A stadium, not a circle — the pressed/selected shape now spans
      // letter + number, which is taller than it is wide.
      borderRadius: BorderRadius.circular(theme.radiusPill),
      // No outer padding: this cell's width IS the stadium's width, and
      // the row lays seven of them out with `spaceBetween` against a
      // fixed content width. Any outer padding inflates the cell without
      // being part of the visible pill, which overflowed the row by 28px
      // when tried. The inner padding below is what gives the stadium its
      // shape.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(theme.radiusPill),
        ),
        child: Padding(
          // `spacingSm`, not `spacingXs` — requested directly: the
          // selected-day stadium's hit/active area read too thin.
          // Widening it eats into the `spaceBetween` gap between cells
          // rather than growing the row's own bounds (see this row's
          // `spaceBetween`-over-natural-width comment above).
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingSm,
            vertical: theme.spacingSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textCaption.copyWith(
                  color: theme.colorTextTertiary,
                ),
              ),
              SizedBox(height: theme.spacingSm),
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
