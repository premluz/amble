import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/calendar_providers.dart';

/// How often open views re-read the device calendars when nothing tells us
/// they changed (Google accounts, for one, sync on their own schedule).
const calendarPollInterval = Duration(minutes: 5);

/// A burst of change notifications (a sync delivers many) becomes one read.
const _changeDebounce = Duration(seconds: 1);

/// macOS posts here whenever the Calendar database changes.
const _changesChannel = MethodChannel('com.amble/calendar_changes');

/// Keeps device-calendar events current without a manual refresh: re-reads
/// when the app returns to the front, when macOS reports a calendar change,
/// and every [calendarPollInterval]. Wraps the app; draws only [child].
class CalendarAutoRefresh extends ConsumerStatefulWidget {
  const CalendarAutoRefresh({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CalendarAutoRefresh> createState() =>
      _CalendarAutoRefreshState();
}

class _CalendarAutoRefreshState extends ConsumerState<CalendarAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _debounce;

  void _refresh() =>
      ref.read(externalCalendarRefreshProvider.notifier).refresh();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(calendarPollInterval, (_) => _refresh());
    _changesChannel.setMethodCallHandler((call) async {
      if (call.method != 'changed') return;
      _debounce?.cancel();
      _debounce = Timer(_changeDebounce, _refresh);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changesChannel.setMethodCallHandler(null);
    _poll?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
