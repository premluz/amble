import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock_provider.dart';

part 'selected_date_provider.g.dart';

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// The day currently shown on the Timeline screen. Screen-local UI state,
/// not app-level — lives under features/timeline/, not shared/providers/,
/// per the distinction drawn in docs/DECISIONS.md (Phase 1).
@riverpod
class SelectedDate extends _$SelectedDate {
  @override
  DateTime build() => _dateOnly(ref.read(nowProvider)());

  void goToToday() => state = _dateOnly(ref.read(nowProvider)());

  void goToPreviousDay() => state = state.subtract(const Duration(days: 1));

  void goToNextDay() => state = state.add(const Duration(days: 1));

  void goTo(DateTime date) => state = _dateOnly(date);
}
