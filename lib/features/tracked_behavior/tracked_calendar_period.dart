import '../../shared/models/tracked_behavior_view_mode.dart';

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
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Calendar period calculations shared by the Tracked header and its rows.
abstract final class TrackedCalendarPeriod {
  static DateTime start(DateTime date, TrackedBehaviorViewMode mode) {
    final day = DateTime(date.year, date.month, date.day);
    return switch (mode) {
      TrackedBehaviorViewMode.weekly => day.subtract(
        Duration(days: day.weekday - 1),
      ),
      TrackedBehaviorViewMode.monthly => DateTime(day.year, day.month),
      TrackedBehaviorViewMode.sixMonthly => DateTime(
        day.year,
        day.month <= 6 ? 1 : 7,
      ),
    };
  }

  static DateTime end(DateTime date, TrackedBehaviorViewMode mode) {
    final first = start(date, mode);
    return switch (mode) {
      TrackedBehaviorViewMode.weekly => first.add(const Duration(days: 6)),
      TrackedBehaviorViewMode.monthly => DateTime(
        first.year,
        first.month + 1,
        0,
      ),
      TrackedBehaviorViewMode.sixMonthly => DateTime(
        first.year,
        first.month + 6,
        0,
      ),
    };
  }

  static DateTime shift(
    DateTime date,
    TrackedBehaviorViewMode mode,
    int direction,
  ) {
    if (direction != -1 && direction != 1) {
      throw ArgumentError.value(direction, 'direction', 'Must be -1 or 1.');
    }
    return switch (mode) {
      TrackedBehaviorViewMode.weekly => DateTime(
        date.year,
        date.month,
        date.day + 7 * direction,
      ),
      TrackedBehaviorViewMode.monthly => DateTime(
        date.year,
        date.month + direction,
      ),
      TrackedBehaviorViewMode.sixMonthly => DateTime(
        start(date, mode).year,
        start(date, mode).month + 6 * direction,
      ),
    };
  }

  static String label(DateTime date, TrackedBehaviorViewMode mode) {
    final first = start(date, mode);
    final last = end(date, mode);
    final firstYear = first.year == last.year ? '' : '${first.year} ';
    final lastYear = first.year == last.year ? '' : ' ${last.year}';
    return switch (mode) {
      TrackedBehaviorViewMode.weekly =>
        '${_weekdayNames[first.weekday - 1]} ${first.day} '
            '${_monthNames[first.month - 1].substring(0, 3)} $firstYear– '
            '${_weekdayNames[last.weekday - 1]} ${last.day} '
            '${_monthNames[last.month - 1].substring(0, 3)}'
            '$lastYear',
      TrackedBehaviorViewMode.monthly => _monthNames[date.month - 1],
      TrackedBehaviorViewMode.sixMonthly =>
        '${_monthNames[first.month - 1]} – '
            '${_monthNames[last.month - 1]} ${last.year}',
    };
  }
}
