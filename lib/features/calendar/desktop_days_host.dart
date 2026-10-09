import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../timeline/timeline_screen.dart';
import 'calendar_span.dart';
import 'desktop_calendar_toolbar.dart';
import 'month_view.dart';
import 'week_view.dart';

/// The Days page in the wide layout: the toolbar, then one day (the usual
/// Timeline, in its current display mode), a week, or a month.
class DesktopDaysHost extends ConsumerWidget {
  const DesktopDaysHost({super.key, required this.mode});

  /// The Day view's own display mode (spatial or list), unchanged.
  final TimelineDisplayMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(calendarSpanProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DesktopCalendarToolbar(),
        Expanded(
          child: switch (span) {
            CalendarSpan.day => TimelineScreen(mode: mode),
            CalendarSpan.week => const WeekView(),
            CalendarSpan.month => const MonthView(),
          },
        ),
      ],
    );
  }
}
