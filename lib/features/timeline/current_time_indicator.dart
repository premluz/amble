import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// Horizontal marker at the current time, positioned on the same
/// pixels-per-minute scale as [HourMarkers]/task blocks. Refreshes every
/// minute via a periodic timer — simplest correct option for a clock-driven
/// UI element; see docs/DECISIONS.md for the alternatives considered.
///
/// The current time is labelled in bold at the left, in the same gutter as
/// [HourMarkers]' hour labels, so "now" reads as the emphasised member of
/// that column rather than a separate element — the surrounding hour
/// labels stay muted and secondary by contrast.
class CurrentTimeIndicator extends StatefulWidget {
  const CurrentTimeIndicator({
    super.key,
    this.startHour = 6,
    this.pixelsPerMinute = 1.5,
    this.gutterWidth = 56.0,
  });

  final int startHour;
  final double pixelsPerMinute;

  /// Width of the hour-label gutter this indicator's time label shares
  /// with [HourMarkers], so the two align on the same left edge.
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
    final minutesSinceStart = (_now.hour - widget.startHour) * 60 + _now.minute;
    final top = minutesSinceStart * widget.pixelsPerMinute;

    if (top < 0) return const SizedBox.shrink();

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      // The row is taller than the line itself (the time label sets its
      // height), so shift it up by half to keep the line — not the row's
      // top edge — sitting exactly on the current minute.
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Row(
          children: [
            SizedBox(
              width: widget.gutterWidth,
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
