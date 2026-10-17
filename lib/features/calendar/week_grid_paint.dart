import 'package:flutter/material.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_hairline.dart';

/// The week's hour labels, down the left edge.
class WeekHourAxis extends StatelessWidget {
  const WeekHourAxis({super.key, required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final style = theme.textCaptionMono.copyWith(
      color: theme.colorTextSecondary,
    );
    return SizedBox(
      width: CalendarGridTokens.weekGutterWidth,
      child: Stack(
        children: [
          for (var hour = 1; hour < Duration.hoursPerDay; hour++)
            Positioned(
              top: hour * hourHeight,
              right: theme.spacingSm,
              child: FractionalTranslation(
                translation: const Offset(0, -.5),
                child: Text(
                  timelineClock(context, TimeOfDay(hour: hour, minute: 0)),
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The faint grid behind the week: a line per hour and a slightly stronger
/// one per day, across the day columns (not the hour axis).
class WeekGridLines extends CustomPainter {
  const WeekGridLines({
    required this.hour,
    required this.day,
    required this.dayCount,
    required this.hourHeight,
  });

  final Color hour;
  final Color day;
  final int dayCount;
  final double hourHeight;

  @override
  void paint(Canvas canvas, Size size) {
    const left = CalendarGridTokens.weekGutterWidth;
    final hourPaint = Paint()
      ..color = hour
      ..strokeWidth = AppHairline.width;
    for (var h = 1; h < Duration.hoursPerDay; h++) {
      final y = h * hourHeight;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), hourPaint);
    }
    final dayPaint = Paint()
      ..color = day
      ..strokeWidth = AppHairline.width;
    final dayWidth = (size.width - left) / dayCount;
    for (var d = 0; d < dayCount; d++) {
      final x = left + d * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dayPaint);
    }
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(WeekGridLines old) =>
      old.hour != hour ||
      old.day != day ||
      old.dayCount != dayCount ||
      old.hourHeight != hourHeight;
}
