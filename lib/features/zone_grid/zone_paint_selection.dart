import 'dart:math' as math;

/// Snapped rectangle in schedule coordinates, independent of widget geometry.
class ZonePaintSelection {
  const ZonePaintSelection(this.firstDay, this.lastDay, this.startMinutes, this.endMinutes);
  factory ZonePaintSelection.between(int dayA, int minuteA, int dayB, int minuteB) {
    final start = (math.min(minuteA, minuteB) ~/ 5 * 5).clamp(0, 1435);
    final end = ((math.max(minuteA, minuteB) / 5).ceil() * 5).clamp(start + 5, 1440);
    return ZonePaintSelection(math.min(dayA,dayB).clamp(1,7), math.max(dayA,dayB).clamp(1,7), start, end);
  }
  final int firstDay, lastDay, startMinutes, endMinutes;
  Set<int> get weekdays => {for (var day = firstDay; day <= lastDay; day++) day};
}
