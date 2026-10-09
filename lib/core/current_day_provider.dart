import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock_provider.dart';

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// Today's calendar date, as last checked — what the "today" dot and the
/// day rollover compare against. Holds no timer of its own: it only moves
/// when [refresh] is called (by `DayRolloverWatcher`, on a minute boundary,
/// app resume, or screen mount), so watching it never keeps a clock alive.
class CurrentDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => _dateOnly(ref.read(nowProvider)());

  /// Re-reads the clock. True when the calendar day has moved on since the
  /// last check — the signal to roll the Day screen over to the new today.
  bool refresh() {
    final today = _dateOnly(ref.read(nowProvider)());
    if (today == state) return false;
    state = today;
    return true;
  }
}

final currentDayProvider = NotifierProvider<CurrentDayNotifier, DateTime>(
  CurrentDayNotifier.new,
);
