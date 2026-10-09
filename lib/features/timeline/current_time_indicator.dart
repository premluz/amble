import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../core/tokens/semantic_theme.dart';
import '../../core/timeline_clock.dart';
import '../../core/wall_clock_watcher.dart';

/// Horizontal marker at the current time, positioned on the same
/// pixels-per-minute scale as the day view's task boundary labels and task
/// blocks. Refreshes every minute via a periodic timer — simplest correct
/// option for a clock-driven UI element; see docs/DECISIONS.md for the
/// alternatives considered.
///
/// The current time is labelled in bold at the left, in the same gutter as
/// the day view's task-boundary time labels (see `TaskBoundaryMarkers`),
/// so "now" reads as the emphasised member of that column rather than a
/// separate element — the surrounding labels stay muted and secondary by
/// contrast.
class CurrentTimeIndicator extends StatefulWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    this.leftInset = 0,
    this.rightInset = 0,
    this.pixelsPerMinute = 1.5,
    this.now = DateTime.now,
  });

  /// Where "now" comes from; the Timeline passes its clock provider so
  /// tests can pin the time.
  final DateTime Function() now;

  /// The day view's visible top/bottom edges — a dynamic, per-day computed
  /// window (see `_DayTimelineState`), not a fixed hour range. "Now" only
  /// renders when it actually falls inside this window; a day clamped to
  /// its tasks' own times can easily not include the real current time.
  final DateTime rangeStart;

  /// The Timeline's horizontal screen padding, which its scroll view no
  /// longer applies itself (so the tap-to-create ripple can reach the
  /// screen edges) — see that widget's own `padding:` note.
  final double leftInset;
  final double rightInset;
  final DateTime rangeEnd;
  final double pixelsPerMinute;

  @override
  State<CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<CurrentTimeIndicator> {
  late DateTime _now = widget.now();

  /// On each minute boundary, and at once when the system time changes —
  /// see [WallClockWatcher].
  late final _clock = WallClockWatcher(
    now: () => widget.now(),
    onChange: () {
      if (mounted) setState(() => _now = widget.now());
    },
  );

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    if (_now.isBefore(widget.rangeStart) || _now.isAfter(widget.rangeEnd)) {
      return const SizedBox.shrink();
    }
    final minutesSinceStart = _now.difference(widget.rangeStart).inMinutes;
    final top = minutesSinceStart * widget.pixelsPerMinute;

    return Positioned(
      top: top,
      // Insets match the Timeline's own horizontal screen padding, which
      // its scroll view no longer applies — see that `padding:` note.
      // Without these the now-line would run flush to both physical
      // screen edges while every task beside it stays inset.
      left: widget.leftInset,
      right: widget.rightInset,
      // The marker's dot/line sit in a fixed `theme.spacingSm`-tall box
      // (see [CurrentTimeMarker]); shifting up by exactly half THAT fixed
      // height lands the dot/line's own center — not the row's, and not
      // the taller pill's — on the true current minute at `top`.
      child: Transform.translate(
        offset: Offset(0, -theme.spacingSm / 2),
        child: CurrentTimeMarker(time: _now),
      ),
    );
  }
}

/// The shared "now" marker row — `[time pill] [gap] [dot] [line]` — drawn
/// by both the spatial view ([CurrentTimeIndicator], positioned at the
/// exact minute) and the non-spatial List view (`ListCurrentTimeMarker`,
/// sitting between rows). One widget, so the two views can never drift
/// into two different "now" looks.
///
/// The time text comes first, the dot after it, then the line — corrected
/// directly: "dot should be after time not in front", so the time reads
/// flush with every hour label in the same column:
/// "09:00 / 09:31 o-------- / 10:00".
class CurrentTimeMarker extends StatelessWidget {
  const CurrentTimeMarker({
    super.key,
    required this.time,
    this.pillSizesRow = false,
  });

  final DateTime time;

  /// False (spatial): the row measures only the dot, and the taller pill
  /// overflows it. Letting the pill size the row there moves the line off
  /// the true minute and — because the indicator shares a Stack with the
  /// task pills — shifts every measured task rect; it broke two
  /// `resize_anchored_edge_test.dart` cases with 48px of drift, twice.
  ///
  /// True (List view): there is no minute-exact y to protect — the marker
  /// is its own row between tasks — so the pill sizes the row normally
  /// and nothing overflows into neighbouring rows.
  final bool pillSizesRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // Filled with the Timeline's OWN background so the pill masks whatever
    // sits beneath it — requested directly: "that current time need to be
    // in bg color pill so when over on top of another hour it doesnt clash
    // legibility". A neutral mask: the red dot/line stay the only accent.
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceTimeline,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          right: theme.spacingXs,
          top: theme.spacingXs / 2,
          bottom: theme.spacingXs / 2,
        ),
        child: Text(
          timelineClock(context, TimeOfDay.fromDateTime(time)),
          // textCaptionMono — a time label, not a name.
          style: theme.textCaptionMono.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (pillSizesRow)
          pill
        else
          // "Paint big, measure small": the pill lays out against
          // unbounded height and overflows this dot-tall box. The
          // enclosing Stack's `Clip.none` keeps the overflow visible.
          SizedBox(
            height: theme.spacingSm,
            child: OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.centerLeft,
              fit: OverflowBoxFit.deferToChild,
              child: pill,
            ),
          ),
        SizedBox(width: theme.spacingXs),
        SizedBox(
          width: theme.spacingSm,
          height: theme.spacingSm,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorTaskAlert,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: theme.spacingSm,
            child: Center(
              child: Container(
                height: theme.borderWidthHairline,
                color: theme.colorTaskAlert,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
