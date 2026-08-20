import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// Left-edge hour labels for the day view — subtle, secondary text color,
/// deliberately not competing with task content. One label per hour from
/// [startHour] to [endHour] inclusive, spaced [pixelsPerMinute] * 60 apart
/// to align with tasks positioned on the same scale.
class HourMarkers extends StatelessWidget {
  const HourMarkers({
    super.key,
    this.startHour = 6,
    this.endHour = 22,
    this.pixelsPerMinute = 1.5,
  });

  final int startHour;
  final int endHour;
  final double pixelsPerMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final hourHeight = 60 * pixelsPerMinute;

    return SizedBox(
      height: (endHour - startHour) * hourHeight,
      child: Stack(
        children: [
          for (var hour = startHour; hour <= endHour; hour++)
            Positioned(
              top: (hour - startHour) * hourHeight,
              left: 0,
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: Text(
                  TimeOfDay(hour: hour, minute: 0).format(context),
                  style: theme.textCaption.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
