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
/// task detail sheet's own Monday-first repeat-day picker (which switched
/// from 3-letter `MON..SUN` labels to this same single-letter
/// M/T/W/T/F/S/S format on 2026-09-22, requested directly).
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
    this.showTodayLabel = true,
  });

  /// The day currently shown as selected in the week strip — NOT
  /// necessarily today. Beyond the small accent dot under today's own
  /// cell, this widget surfaces exactly ONE other "today is special"
  /// signal: the fading "Today" text (see [showTodayLabel]) — everything
  /// else about jumping to/selecting a day still flows through
  /// [onDateSelected] alone, the same as any other date.
  final DateTime selectedDate;

  final ValueChanged<DateTime> onDateSelected;

  /// Whether the fading "Today" text (top-right of the date row, visible
  /// only while [selectedDate] isn't today — see [_TodayFadeLabel]) shows
  /// at all. Defaults true. `AppCalendarHeader`'s own Edit-Mode branch
  /// passes false — requested directly, consistently with the pre-existing
  /// "no Today control while editing" rule this mirrors (see that file's
  /// own doc comment on why the old jump-to-today BUTTON was removed from
  /// Edit Mode; this is the same call extended to the newer passive
  /// label).
  final bool showTodayLabel;

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
        Row(
          children: [
            _DateLabelRow(
              theme: theme,
              monthOf: widget.selectedDate,
              expanded: _expanded,
              onTap: () => _setExpanded(!_expanded),
            ),
            const Spacer(),
            if (widget.showTodayLabel)
              _TodayFadeLabel(
                theme: theme,
                visible: !_isSameDay(widget.selectedDate, today),
                onTap: () => widget.onDateSelected(today),
              ),
          ],
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

/// A small "Today" text at the trailing edge of the date row, fading in
/// the instant the selected day stops being today and fading back out the
/// moment it's today again — requested directly: "if not today selected
/// then we should [show a] small text thin 'Today' fading it on the right
/// hand side of Date expander. It should fade in as soon as 'today date is
/// change' and fade out when it's back on."
///
/// Tapping it jumps back to today — the same "select today" action any
/// other cell in this widget already reports through [onTap], not a new
/// callback: [AppDateAccordion] never assumes "today" is special beyond
/// this row (see its own class doc comment), so "jump to today" is simply
/// "select today's date," reusing the exact same [ValueChanged<DateTime>]
/// contract every other selection in this widget already goes through.
class _TodayFadeLabel extends StatelessWidget {
  const _TodayFadeLabel({
    required this.theme,
    required this.visible,
    required this.onTap,
  });

  final AmbleTheme theme;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Not tappable while invisible — otherwise an exact-fit hit target
      // sitting on top of nothing would silently eat taps meant for
      // whatever's behind this row (there's a `Spacer` here, so nothing
      // else lives at this x today, but this is the same "hidden means
      // hidden, not just transparent" guarantee every other faded-out
      // control in this app already keeps).
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: theme.motionNormal,
        curve: theme.curveStandard,
        child: AppPressFeedback(
          onTap: onTap,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingXs,
              vertical: theme.spacingXs / 2,
            ),
            child: Text(
              'Today',
              style: theme.textCaption.copyWith(
                color: theme.colorTextSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The weekday-letter row + the Mon-Sun day grid, with swipe-to-change-
/// week and press-and-slide day scrubbing — split out of the old
/// `AppCalendarHeader` unchanged in substance, just re-hosted as this
/// widget's own expandable content.
///
/// **Stateful, not stateless** — added directly for the press-and-slide
/// scrub (see [_onScrubMove]): tracking which day the finger is
/// currently over, live, needs `State` this widget didn't need before.
class _WeekStrip extends StatefulWidget {
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
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip>
    with SingleTickerProviderStateMixin {
  /// One key per day column, in Monday-first order — used only to read
  /// each cell's live `RenderBox` bounds during a scrub (see
  /// [_onScrubMove]), never for identity/rebuild purposes.
  final _cellKeys = List.generate(7, (_) => GlobalKey());

  /// How many weeks the strip is showing away from [widget.weekStart] —
  /// purely a VIEWING offset, never the selected day. Requested directly:
  /// "swipe through should not mean changing day, only to see dates of
  /// next week... tap on day is changing only." A completed swipe used to
  /// call `onDateSelected(selectedDate ± 7 days)` — genuinely reassigning
  /// the app-wide selected day just to look at a different week's dates.
  ///
  /// Reset to 0 whenever [widget.weekStart] changes for a reason OTHER
  /// than this offset itself (see [didUpdateWidget]) — i.e. whenever the
  /// SELECTED day actually changed (a tap, "Today," or any other external
  /// cause), the strip snaps back to showing the newly-selected day's own
  /// week, exactly as before this change. Swiping never triggers that
  /// reset itself, since it never touches `selectedDate` at all.
  int _viewedWeekOffset = 0;

  /// [widget.weekStart] shifted by [_viewedWeekOffset] — the week this
  /// strip actually DISPLAYS. Every render/measurement below reads this,
  /// never [widget.weekStart] directly.
  DateTime get _viewedWeekStart =>
      widget.weekStart.add(Duration(days: _viewedWeekOffset * 7));

  /// The day the drag is currently over, while a scrub is in progress —
  /// null the rest of the time. Only used to avoid re-selecting the same
  /// day on every pointer-move event; the actual selection is reported
  /// straight to [AppDateAccordion.onDateSelected] as it changes, not
  /// buffered here.
  int? _scrubbedIndex;

  /// **2026-09-21 — swipe paging, not an instant jump.** Requested
  /// directly: "on swipe left right the calendar we need animation and
  /// actually 'pulling further or previous' days from behind screen and
  /// then 'magnetic' kind of lock to land in position... currently no
  /// animation, numbers just change." Replaces the old bare
  /// `onHorizontalDragEnd`-only jump (still present in spirit — a
  /// completed swipe still steps 7 days — but now the whole week visibly
  /// slides rather than snapping in one frame).
  ///
  /// [_dragPixels] is the live horizontal offset while a finger is down —
  /// the CURRENT week's row is drawn shifted by this, and the previous/
  /// next week's row is drawn one strip-width further out in the same
  /// direction, so dragging visibly "pulls" the adjacent week in from
  /// off-screen rather than the numbers just changing in place. Reset to
  /// 0 once a page settles.
  double _dragPixels = 0;

  /// The strip's own measured width — needed to know how far "one week"
  /// is in pixels (for clamping the drag and for where the adjacent
  /// week's row sits at rest), captured via [LayoutBuilder] in [build]
  /// since this widget has no fixed width of its own.
  double _stripWidth = 0;

  /// Drives [_dragPixels] from wherever the finger released it to its
  /// resting value (0, or a full ±[_stripWidth] before the week actually
  /// steps) — the "magnetic lock" settle. `curveStandard`, not a bespoke
  /// spring/overshoot curve: this design system has no spring token yet
  /// (confirmed by survey — only `curveStandard`/`curveDecelerate`
  /// exist), and `curveStandard`'s own fast-out-slow-in shape already
  /// reads as "decisive then eased to a stop" without inventing a new
  /// primitive for one widget.
  late final AnimationController _settleController = AnimationController(
    vsync: this,
    duration: widget.theme.motionNormal,
  );

  @override
  void didUpdateWidget(_WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent derives `weekStart` from `selectedDate` (see
    // `_AppDateAccordionState.build`), so this only fires when the
    // SELECTED day actually changed — a tap, "Today," or any other
    // external cause, never a swipe (see [_viewedWeekOffset]'s own doc
    // comment). Snap the view back to the newly-selected day's own week.
    if (oldWidget.weekStart != widget.weekStart && _viewedWeekOffset != 0) {
      setState(() => _viewedWeekOffset = 0);
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  /// Press-and-slide day scrubbing — requested directly: holding the
  /// finger down and sliding it across the row should "turn" through the
  /// days it passes over, selecting whichever one the finger is
  /// currently on top of, smoothly, rather than requiring a distinct tap
  /// per day.
  ///
  /// Driven by [GestureDetector.onLongPressMoveUpdate], not
  /// `onHorizontalDragUpdate` — a plain horizontal drag is the SAME
  /// gesture family the week-jump swipe already owns (see [build]'s own
  /// `GestureDetector`), and Flutter's gesture arena would have to
  /// arbitrarily pick one recognizer to win, which is exactly what broke
  /// `app_calendar_header_test.dart`'s swipe test when both lived on one
  /// drag recognizer: the scrub fired mid-flick and left the selected
  /// day wherever the finger happened to be when the SIMULATED drag
  /// ended, not 7 days out. A long-press-triggered drag is a genuinely
  /// different recognizer, so the two coexist without the arena having
  /// to guess — a quick swipe never holds long enough to trigger this
  /// one at all, and a deliberate press-and-slide never reads as a flick.
  ///
  /// Hit-tests [globalPosition] against each cell's own `RenderBox`
  /// (via [_cellKeys]) rather than dividing the row width into 7 equal
  /// slices — the cells are NOT evenly spaced (`spaceBetween` over
  /// naturally-sized content, see [_WeekStrip]'s own historical comment
  /// on why), so a slice-based mapping would desync from the visible
  /// cells, especially at the row's own edges.
  ///
  /// The bounds checked are padded out by the SAME `theme.spacingXs`
  /// [_WeekDayCell]'s own enlarged (but invisible) tap target uses — the
  /// `RenderBox` behind [_cellKeys] is that cell's `Stack`, sized to the
  /// visible pill only (a `Positioned` child painting outside a `Stack`'s
  /// bounds doesn't grow `Stack.size`), so without this the scrub would
  /// recognize a smaller area than an actual tap on the same cell does.
  void _onScrubMove(Offset globalPosition) {
    final reach = widget.theme.spacingXs;
    for (var i = 0; i < _cellKeys.length; i++) {
      final box = _cellKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final local = box.globalToLocal(globalPosition);
      if (local.dx < -reach ||
          local.dy < -reach ||
          local.dx > box.size.width + reach ||
          local.dy > box.size.height + reach) {
        continue;
      }
      if (_scrubbedIndex == i) return;
      _scrubbedIndex = i;
      widget.onDateSelected(_viewedWeekStart.add(Duration(days: i)));
      return;
    }
  }

  void _onPageDragUpdate(DragUpdateDetails details) {
    if (_stripWidth <= 0) return;
    setState(() {
      // Clamped to one strip-width either way — past that, dragging
      // further wouldn't reveal anything new (the week beyond the
      // adjacent one is never drawn), so the finger would otherwise
      // outrun the visible motion.
      _dragPixels = (_dragPixels + details.delta.dx).clamp(
        -_stripWidth,
        _stripWidth,
      );
    });
  }

  /// Resolves the drag to a resting point — commit a full week step, or
  /// spring back to where this page started — then animates [_dragPixels]
  /// there. A fast flick commits regardless of how far the finger
  /// actually travelled (matches the pre-existing velocity-only jump this
  /// replaces); otherwise it's purely distance: past half the strip's own
  /// width counts as "far enough," short of that snaps back. Requested
  /// directly as "magnetic... calm but decisive."
  ///
  /// **2026-09-26 — commits to [_viewedWeekOffset], not [onDateSelected].**
  /// Reported directly: "swipe through should not mean changing day, only
  /// to see dates of next week." A completed swipe used to reassign
  /// `selectedDate` itself (`selectedDate ± 7 days`), which moved the
  /// app-wide selected day — and everything reading it (the Timeline
  /// below this header) — just because the user wanted to glance at next
  /// week's dates. Swiping now only changes which week this STRIP shows;
  /// tapping a day in it is still the only thing that calls
  /// [onDateSelected] (see [_onScrubMove] and each `_WeekDayCell`'s own
  /// `onTap`).
  void _onPageDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const flingVelocityThreshold = 400.0;
    final pastHalfway = _dragPixels.abs() > _stripWidth / 2;
    final committing = velocity.abs() > flingVelocityThreshold || pastHalfway;

    // Sign of the COMMIT, not of the raw drag/velocity — dragging left
    // (negative dx) reveals the NEXT week, matching this row's own
    // pre-existing `velocity < 0 ? 7 : -7` direction convention.
    final stepsForward =
        committing && (velocity != 0 ? velocity < 0 : _dragPixels < 0);
    final target = !committing
        ? 0.0
        : (stepsForward ? -_stripWidth : _stripWidth);

    _settleController
      ..stop()
      ..value = 0;
    final animation = Tween<double>(begin: _dragPixels, end: target).animate(
      CurvedAnimation(
        parent: _settleController,
        curve: widget.theme.curveStandard,
      ),
    );
    void tick() => setState(() => _dragPixels = animation.value);
    animation.addListener(tick);
    _settleController.forward().whenCompleteOrCancel(() {
      animation.removeListener(tick);
      if (committing) {
        _viewedWeekOffset += stepsForward ? 1 : -1;
      }
      // Reset AFTER stepping the offset — both land in the SAME setState
      // below, so the strip never visibly shows the old week sitting at
      // rest before the new one takes over.
      setState(() => _dragPixels = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
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
        //
        // Horizontal swipe pages the visible week back/forward — a
        // SEPARATE `GestureDetector` from the press-and-slide scrub below
        // (see [_onScrubMove]'s own doc comment on why the two must not
        // share one drag recognizer) — a quick swipe is caught here
        // before it holds long enough for a long-press to even register.
        //
        // **2026-09-21 — the week visibly slides, not an instant jump.**
        // Requested directly: dragging now "pulls" the adjacent week in
        // from off-screen, following the finger live, and releasing
        // either commits the step (a full 7-day slide-through, "magnetic"
        // settle at the end) or springs back to the current week if the
        // drag didn't go far/fast enough — see [_onPageDragEnd]'s own doc
        // comment for the exact commit rule.
        LayoutBuilder(
          builder: (context, constraints) {
            // Captured every build (post-frame would lag one frame behind
            // a size change, e.g. the accordion's own first expand) —
            // cheap, just a field write, not a real layout cost.
            _stripWidth = constraints.maxWidth;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onPageDragUpdate,
              onHorizontalDragEnd: _onPageDragEnd,
              // Opaque hit-testing needs a real, non-shrinking bounding
              // box — `Row` alone (no longer stretched by `Expanded`
              // children) would shrink to the sum of the 7 cells' own
              // natural widths, leaving the gaps BETWEEN them (most of
              // this row's actual area) unable to catch the swipe.
              child: ClipRect(
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    // `Clip.none` on the Stack itself — the `ClipRect`
                    // above already bounds the whole strip; letting the
                    // Stack ALSO clip its children would cut off the
                    // adjacent week's row exactly where it's supposed to
                    // be visible (still sliding in) rather than only once
                    // it's fully off-screen.
                    clipBehavior: Clip.none,
                    children: [
                      // The week reached by continuing to drag LEFT
                      // (finger moving toward negative dx) — sits one
                      // strip-width to the right at rest, only entering
                      // view as `_dragPixels` goes negative.
                      if (_dragPixels < 0)
                        Transform.translate(
                          offset: Offset(_dragPixels + _stripWidth, 0),
                          child: _WeekDayRow(
                            theme: theme,
                            weekStart: _viewedWeekStart.add(
                              const Duration(days: 7),
                            ),
                            today: widget.today,
                            selectedDate: widget.selectedDate,
                            cellKeys: null,
                            onDateSelected: widget.onDateSelected,
                          ),
                        ),
                      if (_dragPixels > 0)
                        Transform.translate(
                          offset: Offset(_dragPixels - _stripWidth, 0),
                          child: _WeekDayRow(
                            theme: theme,
                            weekStart: _viewedWeekStart.subtract(
                              const Duration(days: 7),
                            ),
                            today: widget.today,
                            selectedDate: widget.selectedDate,
                            cellKeys: null,
                            onDateSelected: widget.onDateSelected,
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(_dragPixels, 0),
                        child: _WeekDayRow(
                          theme: theme,
                          weekStart: _viewedWeekStart,
                          today: widget.today,
                          selectedDate: widget.selectedDate,
                          // Only the settled (current) week's cells are
                          // real day-scrub targets — mid-drag, a
                          // long-press has nothing stable to scrub
                          // against anyway.
                          cellKeys: _cellKeys,
                          onDateSelected: widget.onDateSelected,
                          onScrubMove: _onScrubMove,
                          onScrubEnd: () => _scrubbedIndex = null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One Mon-Sun day row, at a given [weekStart] — extracted so [_WeekStrip]
/// can render three of these stacked (previous/current/next) for the
/// swipe-paging slide (see that widget's own `build`). Only the CURRENT
/// (settled) instance is wired for day-scrub (`cellKeys`/`onScrubMove`/
/// `onScrubEnd` all non-null) — the adjacent, still-sliding rows are
/// display-only until a page-step lands and one of them becomes current.
class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.theme,
    required this.weekStart,
    required this.today,
    required this.selectedDate,
    required this.cellKeys,
    required this.onDateSelected,
    this.onScrubMove,
    this.onScrubEnd,
  });

  final AmbleTheme theme;
  final DateTime weekStart;
  final DateTime today;
  final DateTime selectedDate;
  final List<GlobalKey>? cellKeys;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<Offset>? onScrubMove;
  final VoidCallback? onScrubEnd;

  @override
  Widget build(BuildContext context) {
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
    // Each cell renders its own letter above its own number, so one
    // widget owns the whole column and can carry a single tap target
    // and selection fill spanning both — see `_WeekDayCell`.
    //
    // **2026-09-21 — the selection fill is no longer per-cell.** Each
    // `_WeekDayCell` used to own an `AnimatedContainer` that cross-faded
    // its own background in/out — moving selection from one day to
    // another read as one fill fading out while a SEPARATE fill faded in
    // elsewhere, never as one thing travelling. Requested directly: "the
    // active indicator (bg)... enlarges and slides and reduces size to
    // arrive at actual size and spot like gooey kind of thing." A single
    // shared [_WeekDaySelectionIndicator] now paints behind the whole row
    // (see that widget's own doc comment), and `_WeekDayCell` renders no
    // fill of its own at all any more — only the text weight/color and
    // the today-dot still respond to `isSelected`/`isToday`.
    final indicatorTarget =
        selectedDate.isBefore(weekStart) ||
            selectedDate.isAfter(weekStart.add(const Duration(days: 6)))
        ? null
        : selectedDate.difference(weekStart).inDays;

    final row = SizedBox(
      width: double.infinity,
      child: _WeekDaySelectionIndicator(
        theme: theme,
        // Only the current (settled) row ever has real `cellKeys` to
        // measure — the sliding adjacent pages (`onScrubMove` also null
        // for those) render the indicator-free variant instead, since
        // there is nothing stable to measure mid-drag and no selection
        // ever rests on them anyway.
        cellKeys: onScrubMove != null ? cellKeys : null,
        selectedIndex: indicatorTarget,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              _WeekDayCell(
                key: cellKeys?[i],
                theme: theme,
                label: _weekdayAbbreviations[i],
                date: weekStart.add(Duration(days: i)),
                isToday: _isSameDay(weekStart.add(Duration(days: i)), today),
                isSelected: _isSameDay(
                  weekStart.add(Duration(days: i)),
                  selectedDate,
                ),
                onTap: () => onDateSelected(weekStart.add(Duration(days: i))),
              ),
          ],
        ),
      ),
    );

    if (onScrubMove == null) return row;

    // The scrub's own `GestureDetector` wraps just the `Row`, not the
    // whole swipe target the caller owns — a long-press has to start ON
    // one of the day cells to mean anything (there is nothing to scrub
    // FROM otherwise), where the swipe's own hit area can reasonably
    // start anywhere across the full strip width.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => onScrubMove!(details.globalPosition),
      onLongPressMoveUpdate: (details) => onScrubMove!(details.globalPosition),
      onLongPressEnd: (_) => onScrubEnd!(),
      onLongPressCancel: onScrubEnd,
      child: row,
    );
  }
}

/// Paints ONE shared selection fill behind [child]'s row of day cells,
/// animating between cells rather than letting each cell cross-fade its
/// own — requested directly: "active indicator (bg)... enlarges and
/// slides and reduces size to arrive at actual size and spot like gooey
/// kind of thing."
///
/// **How the geometry is found.** [cellKeys] are the SAME keys
/// [_WeekStripState] already attaches to each `_WeekDayCell` for day-
/// scrub hit-testing — this widget reads their `RenderBox` bounds (via
/// `globalToLocal` against its own `RenderBox`) after every frame to
/// learn where the currently-selected cell actually sits, exactly the
/// same "resolve real geometry through a GlobalKey" technique this file
/// already uses for scrub hit-testing and drop-target checks elsewhere
/// in this app. There is no other way to know a cell's pixel position up
/// front: cells are naturally sized (`spaceBetween`, not fixed columns —
/// see this row's own historical layout comment), so their x-positions
/// only exist once a real layout pass has actually run.
///
/// **A plain move, not a stretch** (2026-09-21, reversing the original
/// "gooey" squash-and-stretch design below) — requested directly: "the
/// 'active' highlight animation... should not have that scale width
/// thing, just move ease (slowing toward end) fast decisive, smooth, no
/// gooey thing." The indicator now animates a single `Rect.lerp` between
/// [_fromRect] and [_toRect] on [AmbleTheme.curveDecelerate] (full speed
/// immediately, then decelerating into the landing) — no union-rect
/// stretch, no contraction phase.
class _WeekDaySelectionIndicator extends StatefulWidget {
  const _WeekDaySelectionIndicator({
    required this.theme,
    required this.cellKeys,
    required this.selectedIndex,
    required this.child,
  });

  final AmbleTheme theme;
  final List<GlobalKey>? cellKeys;

  /// Which of the 7 cells is selected, or null if the selected date isn't
  /// in this row at all (only possible for the sliding adjacent-week
  /// rows mid-drag — the current row's own selection is always one of
  /// its 7 days by construction, since [AppDateAccordion] only ever
  /// calls back with a date, and [_WeekStripState] derives `weekStart`
  /// FROM `selectedDate`).
  final int? selectedIndex;

  final Widget child;

  @override
  State<_WeekDaySelectionIndicator> createState() =>
      _WeekDaySelectionIndicatorState();
}

class _WeekDaySelectionIndicatorState extends State<_WeekDaySelectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.theme.motionNormal,
  );

  /// Eases the controller's own raw linear value — "fast decisive...
  /// slowing toward end," requested directly. Hoisted as a field (not
  /// rebuilt per frame) since [AmbleTheme.curveDecelerate] doesn't change
  /// after `initState`.
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _controller,
    curve: widget.theme.curveDecelerate,
  );

  /// The indicator's own on-screen rect (in this widget's local
  /// coordinates) at the START of the current animation — null before
  /// the first real measurement lands, or once nothing is selected in
  /// this row.
  Rect? _fromRect;

  /// ...and at its END — where the animation (or the very first
  /// measurement, with no animation at all) is heading.
  Rect? _toRect;

  int? _lastSelectedIndex;

  @override
  void initState() {
    super.initState();
    _lastSelectedIndex = widget.selectedIndex;
    // The first frame can't know any cell's real geometry yet — nothing
    // has laid out. One post-frame callback resolves the initial rect
    // with no animation (the indicator should simply BE at the selected
    // cell on first paint, not slide in from nowhere).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncToSelection(animate: false),
    );
  }

  @override
  void didUpdateWidget(_WeekDaySelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _lastSelectedIndex) {
      _lastSelectedIndex = widget.selectedIndex;
      // Selection changed — resolve the NEW cell's rect once its own
      // frame has laid out, animating from wherever the indicator
      // currently sits.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncToSelection(animate: true),
      );
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  Rect? _measureCellRect(int index) {
    final keys = widget.cellKeys;
    final renderBox = context.findRenderObject();
    if (keys == null || renderBox is! RenderBox || !renderBox.attached) {
      return null;
    }
    final cellBox =
        keys[index].currentContext?.findRenderObject() as RenderBox?;
    if (cellBox == null || !cellBox.attached) return null;
    final topLeft = renderBox.globalToLocal(cellBox.localToGlobal(Offset.zero));
    return topLeft & cellBox.size;
  }

  void _syncToSelection({required bool animate}) {
    if (!mounted) return;
    final index = widget.selectedIndex;
    if (index == null) {
      setState(() {
        _fromRect = null;
        _toRect = null;
      });
      return;
    }
    final target = _measureCellRect(index);
    if (target == null) return;
    setState(() {
      _fromRect = animate ? (_toRect ?? target) : target;
      _toRect = target;
    });
    if (animate && _fromRect != target) {
      _controller
        ..stop()
        ..value = 0
        ..forward();
    } else {
      _controller.value = 1;
    }
  }

  /// A plain rect lerp from [_fromRect] to [_toRect] — no stretch, no
  /// union, no contraction phase. [t] is expected to already be eased
  /// (see [build]'s `CurvedAnimation`, `theme.curveDecelerate`), not the
  /// controller's own raw linear value.
  Rect _rectAt(double t) {
    final from = _fromRect;
    final to = _toRect;
    if (from == null || to == null) return to ?? Rect.zero;
    return Rect.lerp(from, to, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          // curveDecelerate — full speed immediately, then decelerating
          // into the landing ("fast decisive... slowing toward end"),
          // matching this row's other motion language rather than the
          // controller's own raw linear value.
          animation: _eased,
          builder: (context, child) {
            final rect = _rectAt(_eased.value);
            if (_toRect == null) return const SizedBox.shrink();
            return Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorSurfaceField,
                  borderRadius: BorderRadius.circular(theme.radiusPill),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    super.key,
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
    // **2026-09-21 — no fill of its own any more.** Used to be an
    // `AnimatedContainer` cross-fading `theme.colorSurfaceField` in/out
    // per cell; that background now lives entirely in the shared
    // `_WeekDaySelectionIndicator` painted behind the whole row (see
    // `_WeekDayRow`'s own doc comment on why) — this cell only reacts to
    // `isSelected`/`isToday` through text weight/color and the today-dot,
    // same "background marks selection, dot marks today" split
    // `AppCalendarHeader`'s own predecessor used for the SHAPE of the
    // signal, just not the ownership of the fill any more.
    //
    // **The letter lives INSIDE this cell, and the tap target is a
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
    // ripple.
    final pill = AppPressFeedback(
      onTap: onTap,
      // A stadium, not a circle — the pressed shape now spans letter +
      // number, which is taller than it is wide.
      borderRadius: BorderRadius.circular(theme.radiusPill),
      // No outer padding: this cell's width IS the stadium's width, and
      // the row lays seven of them out with `spaceBetween` against a
      // fixed content width. Any outer padding inflates the cell without
      // being part of the visible pill, which overflowed the row by 28px
      // when tried. The inner padding below is what gives the stadium its
      // shape.
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
              style: theme.textCaption.copyWith(color: theme.colorTextTertiary),
            ),
            SizedBox(height: theme.spacingSm),
            // `_dayNumberMinWidth`, not a bare Text — requested
            // directly: a 1-digit day ("3") sized this cell narrower
            // than a 2-digit one ("31"), so cells visibly resized as
            // the visible week changed. Reserves enough width for two
            // digits at all times (measured against the token's own
            // monospace-adjacent numeral width, see that constant's own
            // doc comment) so every cell stays the same width whether
            // its day number is one digit or two.
            SizedBox(
              width: _dayNumberMinWidth(theme),
              child: Text(
                '${date.day}',
                textAlign: TextAlign.center,
                // **2026-09-26 — real bug, fixed.** Some day numbers ("20",
                // "30") wrapped onto a second line while most ("21", "22")
                // stayed on one, reported directly against a screenshot.
                // `_dayNumberMinWidth` reserves the box width by measuring
                // "88" at BOLD weight, but this Text had no
                // `softWrap`/`maxLines` — if any real day number's glyph
                // width (bold "0"/"3"/"2" happen to run wider than bold
                // "8" in this font) exceeded that reserved width by even a
                // fraction of a pixel, Flutter wrapped it instead of
                // letting it overflow. A day number is always exactly 1-2
                // digits; it must render as one line or not at all, never
                // wrap.
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: theme.textCaption.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
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
    );

    // Hit area wider than the visible pill — requested directly ("only
    // hit area, not visually active highlight or hover"), so this only
    // grows what catches a tap, never the stadium fill or its padding
    // above.
    //
    // A `Stack` sized to `pill` (its only non-positioned child) with a
    // `Positioned.fill`, negative-inset `GestureDetector` layered
    // BEHIND it — the standard way to extend a hit area past a widget's
    // own paint bounds without changing its layout size. Critically,
    // this whole `_WeekDayCell` still occupies exactly `pill`'s own
    // footprint in the `spaceBetween` row above (a real `Padding` here
    // would instead grow that footprint, shoving every cell after it
    // further along and un-flushing the last day from the row's
    // trailing edge — the exact regression this row's own `spaceBetween`
    // comment documents from an earlier attempt).
    //
    // `theme.spacingXs` of extra reach on every side — on TOP of the
    // `spacingSm` the pill's own padding already gives the visible hit
    // area, so cells this close together would start overlapping hit
    // areas with a bigger number; `spacingXs` is deliberately modest.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -theme.spacingXs,
          top: -theme.spacingXs,
          right: -theme.spacingXs,
          bottom: -theme.spacingXs,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
          ),
        ),
        pill,
      ],
    );
  }
}

/// The width reserved for [_WeekDayCell]'s own day-number `Text` —
/// measured against "88" (two wide digits) at bold weight, the widest a
/// real day number ever renders (the selected cell's own bold weight is
/// wider than the unselected regular weight, so this measures the
/// heavier one to cover both). [TextPainter], the standard way to measure
/// text outside a real layout pass — the same technique `app_tab_switch
/// .dart`'s own `_estimateSegmentWidth` uses for an analogous "reserve a
/// stable width" need.
double _dayNumberMinWidth(AmbleTheme theme) {
  final painter = TextPainter(
    text: TextSpan(
      text: '88',
      style: theme.textCaption.copyWith(fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}
