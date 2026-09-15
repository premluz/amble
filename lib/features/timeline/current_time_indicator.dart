import 'dart:async';

import 'package:flutter/material.dart';

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
      // Shifted up by half the DOT's height (the row's tallest sizing
      // child) so the line — not the row's top edge — sits exactly on the
      // current minute.
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        // **Dot and line start at the left inset, flush with the hour
        // labels** — requested directly ("the red line with dot should
        // extend to the left more"). The time no longer reserves a gutter
        // ahead of them; it paints OVER the line instead, which is what
        // lets the marker span nearly the full width.
        //
        // **The pill is a NON-SIZING overlay** (`Positioned` + `Clip.none`),
        // deliberately. A first attempt made it an ordinary Stack child,
        // which sized the whole row to the pill's ~20px instead of the
        // dot's 8px — and since this row is `FractionalTranslation`-ed by
        // half its own height, that moved the rendered line and broke two
        // `resize_anchored_edge_test.dart` cases measuring a pill in the
        // same tree (48px of bottom drift against a <2px tolerance). The
        // row's height must stay the dot's height, whatever the pill does.
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Row(
              children: [
                Container(
                  width: theme.spacingSm,
                  height: theme.spacingSm,
                  decoration: BoxDecoration(
                    color: theme.colorTaskAlert,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: theme.borderWidthHairline,
                    color: theme.colorTaskAlert,
                  ),
                ),
              ],
            ),
            // Filled with the Timeline's OWN background so the pill masks
            // whatever sits beneath it — requested directly: "that current
            // time need to be in bg color pill so when over on top of
            // another hour it doesnt clash legibility". A neutral mask, not
            // an accent badge: the red line stays the only accent here.
            //
            // Offset past the dot so the two never overlap.
            Positioned(
              left: theme.spacingSm * 2,
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
          ],
        ),
      ),
    );
  }
}
