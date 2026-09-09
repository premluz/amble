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
    this.gutterWidth = 56.0,
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

  /// Width of the time-label gutter this indicator's time label shares
  /// with `TaskBoundaryMarkers`, so the two align on the same left edge.
  final double gutterWidth;

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
      // The row is taller than the line itself (the time label sets its
      // height), so shift it up by half to keep the line — not the row's
      // top edge — sitting exactly on the current minute.
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Row(
          children: [
            SizedBox(
              // gutterWidth arrives already carrying the screen padding
              // (see the Timeline's own hourGutterWidth); this Positioned
              // has separately shifted the whole row right by that same
              // amount, so take it back off here or the label would be
              // double-indented.
              width: widget.gutterWidth - widget.leftInset,
              child: Text(
                TimeOfDay.fromDateTime(_now).format(context),
                style: theme.textCaption.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
      ),
    );
  }
}
