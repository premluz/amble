import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'zone_grid_week_provider.g.dart';

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// The Monday of the week the grid displays. Screen-local, ephemeral —
/// same reasoning as `selected_date_provider.dart`: the grid always opens
/// on the CURRENT week (not a persisted "last viewed week"), so a returning
/// user never reopens onto a stale one.
///
/// Monday, not Sunday — `AppCalendarHeader`'s own week grid starts on
/// Sunday (matching the reference screenshot it was built from), but this
/// screen's own mockup showed M/T/W/T/F/S/S, so it anchors to Monday
/// instead. The two week-starts are independent by design: this screen
/// has no relationship to the Timeline's own day-strip.
@riverpod
class ZoneGridWeek extends _$ZoneGridWeek {
  @override
  DateTime build() => _mondayOf(DateTime.now());

  void goToPreviousWeek() => state = state.subtract(const Duration(days: 7));

  void goToNextWeek() => state = state.add(const Duration(days: 7));

  void goToCurrentWeek() => state = _mondayOf(DateTime.now());
}

DateTime _mondayOf(DateTime date) {
  final d = _dateOnly(date);
  // DateTime.weekday is 1 (Monday) - 7 (Sunday), so this is already the
  // "days since Monday" count with no wraparound needed.
  return d.subtract(Duration(days: d.weekday - 1));
}

/// The 7 calendar days of the week starting at [monday], in order.
List<DateTime> daysOfWeekFrom(DateTime monday) => [
  for (var i = 0; i < 7; i++) monday.add(Duration(days: i)),
];
