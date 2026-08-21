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
    this.hideLabelNear,
  });

  final int startHour;
  final int endHour;
  final double pixelsPerMinute;

  /// A time whose nearest hour label should be omitted, so
  /// [CurrentTimeIndicator]'s bold "now" label doesn't render on top of a
  /// muted hour label in the same gutter. Null keeps every hour label.
  final DateTime? hideLabelNear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final hourHeight = 60 * pixelsPerMinute;

    return SizedBox(
      height: (endHour - startHour) * hourHeight,
      child: Stack(
        children: [
          for (var hour = startHour; hour <= endHour; hour++)
            if (!_isHiddenByNowLabel(hour, theme))
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

  /// Whether [hour]'s label sits close enough to the current-time label to
  /// visually collide with it. The threshold is the label's own rendered
  /// line height, derived from the type tokens, so this scales with the
  /// type scale instead of assuming a fixed pixel gap.
  bool _isHiddenByNowLabel(int hour, AmbleTheme theme) {
    final now = hideLabelNear;
    if (now == null) return false;
    final caption = theme.textCaption;
    final lineHeight = (caption.fontSize ?? 0) * (caption.height ?? 1);
    final minutesApart = ((now.hour - hour) * 60 + now.minute).abs();
    return minutesApart * pixelsPerMinute < lineHeight;
  }
}
