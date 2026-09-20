import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../core/tokens/semantic_theme.dart';

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
  });

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
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
      // **The time text starts at the SAME x every other hour label
      // does, dot AFTER it, then the line** — corrected directly:
      // "currently is (note is not aligned with other hours and dot
      // should be after time not in front)". The previous layout put
      // the dot first and overlaid the time pill on top of the line
      // starting past it — reading as "dot, then time", and starting to
      // the right of where "09:00"/"10:00" themselves start, so "09:31"
      // visually failed to line up with its own neighbours in the same
      // gutter column. A plain `Row` now: [time pill, dot, line], so the
      // text column reads flush with every hour tick above/below it,
      // matching the reference layout exactly:
      // "09:00 / 09:31 o-------- / 10:00".
      //
      // Anchored by `Center`, not `FractionalTranslation` — the pill is
      // taller than the dot/line, so translating the WHOLE row up by
      // half ITS OWN height (as the previous dot-first layout did, back
      // when the dot was the row's only sizing child) would shift the
      // line off the true current-minute y by half the pill's extra
      // height. The dot/line instead sit inside a fixed
      // `theme.spacingSm`-tall `SizedBox` — the same height the dot
      // itself is — centered against the pill via the Row's own
      // `crossAxisAlignment.center`, then the whole thing is shifted up
      // by exactly HALF THAT FIXED HEIGHT so the dot/line's own center
      // (not the row's, and not the pill's) lands on `top`.
      child: Transform.translate(
        offset: Offset(0, -theme.spacingSm / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Filled with the Timeline's OWN background so the pill masks
            // whatever sits beneath it — requested directly: "that current
            // time need to be in bg color pill so when over on top of
            // another hour it doesnt clash legibility". A neutral mask,
            // not an accent badge: the red dot/line stay the only accent
            // here.
            // **NON-SIZING, deliberately** — the pill is taller than the
            // dot, and this whole row is shifted up by half the DOT's
            // height (see the `Transform.translate` above). If the pill
            // is allowed to size the row, the row's height becomes the
            // pill's, the line no longer lands on the true current
            // minute, and — because this widget shares a tree with the
            // task pills — every measured task rect shifts too.
            //
            // That is not hypothetical: it broke two
            // `resize_anchored_edge_test.dart` cases with 48px of bottom
            // drift against a <2px tolerance, TWICE. The pre-rewrite
            // version carried a comment warning about exactly this, and
            // the rewrite (a genuinely wanted reorder — time first, then
            // dot, then line) reintroduced it by making the pill an
            // ordinary `Row` child.
            //
            // `OverflowBox` with a fixed `maxHeight` of the dot's own
            // height is what keeps the row measuring the dot while the
            // pill still paints at its natural size: the child lays out
            // against its own unbounded constraints and simply overflows
            // this box, which is exactly "paint big, measure small".
            // `Clip.none` on the enclosing `Stack` (see `build`'s own
            // `Positioned`) is what lets that overflow stay visible.
            SizedBox(
              height: theme.spacingSm,
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.centerLeft,
                fit: OverflowBoxFit.deferToChild,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceTimeline,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacingXs,
                      vertical: theme.spacingXs / 2,
                    ),
                    child: Text(
                      TimeOfDay.fromDateTime(_now).format(context),
                      style: theme.textCaption.copyWith(
                        color: theme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
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
        ),
      ),
    );
  }
}
