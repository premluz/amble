import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock_provider.dart';
import '../../core/current_day_provider.dart';
import '../../core/wall_clock_watcher.dart';
import 'selected_date_provider.dart';
import 'viewed_time_provider.dart';

/// Rolls the Day screen over to the new today when the calendar date
/// changes — requested directly: "when day actually changed it doesn't
/// refresh (dot) and move to the current selected day when user visits
/// apps again on new day... open always at current day and current hour
/// in the middle."
///
/// Checks on mount (returning to the Day tab, or a cold launch), on each
/// minute boundary (midnight while the app is open), and on app resume —
/// [WallClockWatcher] covers the last two. On a new day it moves
/// [currentDayProvider] (the "today" dot), selects today, and forgets the
/// remembered scroll hour so the fresh day view centers on "now".
///
/// A same-day return leaves the user where they were — only an actual day
/// change resets anything.
class DayRolloverWatcher extends ConsumerStatefulWidget {
  const DayRolloverWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DayRolloverWatcher> createState() => _DayRolloverWatcherState();
}

class _DayRolloverWatcherState extends ConsumerState<DayRolloverWatcher> {
  late final _clock = WallClockWatcher(
    now: () => ref.read(nowProvider)(),
    onChange: _rollOverIfNewDay,
  );

  @override
  void initState() {
    super.initState();
    _clock.start();
    // Post-frame: providers can't be written while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rollOverIfNewDay());
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _rollOverIfNewDay() {
    if (!mounted) return;
    if (!ref.read(currentDayProvider.notifier).refresh()) return;
    // Cleared before selecting today: the new day view reads the
    // remembered hour as it mounts, and must find none.
    ref.read(viewedTimeProvider.notifier).clear();
    ref.read(selectedDateProvider.notifier).goToToday();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
