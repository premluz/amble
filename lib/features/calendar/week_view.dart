import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/current_day_provider.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/providers/calendar_grid_lines_setting.dart';
import '../../shared/providers/week_hour_height_setting.dart';
import '../timeline/selected_date_provider.dart';
import 'calendar_span.dart';
import 'events_on_day.dart';
import 'week_day_column.dart';
import 'week_grid_paint.dart';
import 'week_zoom.dart';
import 'week_zone_bands.dart';

const _hoursPerDay = Duration.hoursPerDay;

/// The wide layout's week: seven day columns on one hour axis, Monday
/// first, scrolled to the morning. A day's header opens it in Day view.
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key});

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  late final _scroll = ScrollController(
    initialScrollOffset:
        CalendarGridTokens.weekFirstVisibleHour *
        ref.read(weekHourHeightSettingProvider),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final days = weekDaysOf(ref.watch(selectedDateProvider));
    final hourHeight = ref.watch(weekHourHeightSettingProvider);
    // Whole-day events have no hour to sit at; Month shows them.
    final events = watchEventsBetween(
      ref,
      days.first,
      days.last,
    ).where((e) => !isAllDay(e)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekHeader(days: days),
        Expanded(
          child: WeekZoom(
            scroll: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                height: _hoursPerDay * hourHeight,
                child: CustomPaint(
                  painter: ref.watch(calendarGridLinesSettingProvider)
                      ? WeekGridLines(
                          hour: theme.colorBorder.withValues(
                            alpha: CalendarGridTokens.hourLineAlpha,
                          ),
                          day: theme.colorBorder.withValues(
                            alpha: CalendarGridTokens.dayLineAlpha,
                          ),
                          dayCount: days.length,
                          hourHeight: hourHeight,
                        )
                      : null,
                  child: Stack(
                    children: [
                      // Zones behind the tasks, one band per run of days.
                      Positioned.fill(child: WeekZoneBands(days: days)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WeekHourAxis(hourHeight: hourHeight),
                          for (final day in days)
                            Expanded(
                              child: WeekDayColumn(
                                day: day,
                                days: days,
                                events: events,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekHeader extends ConsumerWidget {
  const _WeekHeader({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final today = ref.watch(currentDayProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacingXs),
      child: Row(
        children: [
          const SizedBox(width: CalendarGridTokens.weekGutterWidth),
          for (final day in days)
            Expanded(
              child: AppPressFeedback(
                ripple: false,
                onTap: () => openDay(ref, day),
                child: Text(
                  '${weekdayShortNames[day.weekday - 1]} ${day.day}',
                  textAlign: TextAlign.center,
                  style: theme.textLabel.copyWith(
                    color: isSameDay(day, today)
                        ? theme.colorAccent
                        : theme.colorTextSecondary,
                    fontWeight: isSameDay(day, today)
                        ? TypePrimitives.weightSemibold
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows [day] in Day view.
void openDay(WidgetRef ref, DateTime day) {
  ref.read(selectedDateProvider.notifier).goTo(day);
  ref.read(calendarSpanProvider.notifier).set(CalendarSpan.day);
}
