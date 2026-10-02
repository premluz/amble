import 'dart:async';

import 'package:flutter/widgets.dart';

/// Calls [onChange] whenever the wall-clock time a screen shows should move
/// on — requested directly: "make current time respond immediately after a
/// time change in the system."
///
/// - On each real minute boundary, not a minute after the screen mounted
///   (which could leave the label up to 59 s late).
/// - Within about [checkEvery] of the system clock jumping — a manual time
///   or time-zone change. Flutter has no event for that, so each tick
///   checks the wall clock against where the LAST tick left it, expecting
///   [checkEvery] to have passed; if it's off by more than [jumpTolerance],
///   the clock moved underneath us.
/// - As soon as the app comes back to the foreground (where a change made
///   in Settings is usually first seen).
///
/// Owned by a [State]: [start] in `initState`, [dispose] in `dispose`, so no
/// timer outlives the screen.
class WallClockWatcher with WidgetsBindingObserver {
  WallClockWatcher({required this.now, required this.onChange});

  /// Where the time comes from — the app's clock provider, so tests can pin
  /// it (a pinned clock never registers as a jump).
  final DateTime Function() now;
  final VoidCallback onChange;

  static const checkEvery = Duration(seconds: 1);
  static const jumpTolerance = Duration(seconds: 2);

  Timer? _minute;
  Timer? _watch;
  late DateTime _lastWall;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _rebase();
    _watch = Timer.periodic(checkEvery, (_) => _check());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minute?.cancel();
    _watch?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    onChange();
    _rebase();
  }

  void _check() {
    final wall = now();
    final expected = _lastWall.add(checkEvery);
    _lastWall = wall;
    if (wall.difference(expected).abs() <= jumpTolerance) return;
    onChange();
    _scheduleMinute();
  }

  void _rebase() {
    _lastWall = now();
    _scheduleMinute();
  }

  /// One shot to the next minute boundary, then the next, and so on —
  /// recomputed from the wall clock each time, so it never drifts.
  void _scheduleMinute() {
    _minute?.cancel();
    final t = now();
    final next = DateTime(t.year, t.month, t.day, t.hour, t.minute + 1);
    var wait = next.difference(t);
    if (wait <= Duration.zero || wait > const Duration(minutes: 1)) {
      wait = const Duration(minutes: 1);
    }
    _minute = Timer(wait, () {
      onChange();
      _scheduleMinute();
    });
  }
}
