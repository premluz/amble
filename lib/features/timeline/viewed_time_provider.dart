import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time-of-day (minutes since midnight) currently centered in whichever
/// spatial Timeline view (Task or Zone) is on screen — shared across both,
/// so switching between them keeps the same vertical scroll position
/// instead of always re-centering on "now". Requested directly: "changing
/// view should remember scroll position... if I scroll anywhere and change
/// view, [it] should be remembered."
///
/// [ZoneDayTimeline] and `_DayTimeline` are two separate widgets that fully
/// remount on switch (`TimelineScreen`'s own ternary, not a shared
/// ancestor's state) — this provider is the one thing that survives that
/// swap. Each view writes its own center position here as the user
/// scrolls, and reads it back on mount instead of always computing "now".
///
/// Screen-local UI state, not app-level — same shape and reasoning as
/// `RecentlySavedTaskNotifier` (hand-written, not `@riverpod`-generated,
/// for a single transient field with no dependencies). Null until the
/// first scroll of the session, meaning "no remembered position yet" — the
/// initial center-on-now behavior is unchanged for a fresh app open.
class ViewedTimeNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int minutesSinceMidnight) => state = minutesSinceMidnight;
}

final viewedTimeProvider = NotifierProvider<ViewedTimeNotifier, int?>(
  ViewedTimeNotifier.new,
);
