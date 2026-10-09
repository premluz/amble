import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/current_day_provider.dart';
import '../../core/timeline_clock.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/providers/calendar_grid_lines_setting.dart';
import '../timeline/selected_date_provider.dart';
import 'calendar_span.dart';
import 'week_day_column.dart';
import '../../core/widgets/app_hairline.dart';

const _hoursPerDay = Duration.hoursPerDay;

/// The wide layout's week: seven day columns on one hour axis, Monday
/// first, scrolled to the morning. A day's header opens it in Day view.
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key});

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  final _scroll = ScrollController(
    initialScrollOffset:
        CalendarGridTokens.weekFirstVisibleHour *
        CalendarGridTokens.weekHourHeight,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekHeader(days: days),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: _hoursPerDay * CalendarGridTokens.weekHourHeight,
              child: CustomPaint(
                painter: ref.watch(calendarGridLinesSettingProvider)
                    ? _GridLines(
                        hour: theme.colorBorder.withValues(
                          alpha: CalendarGridTokens.hourLineAlpha,
                        ),
                        day: theme.colorBorder.withValues(
                          alpha: CalendarGridTokens.dayLineAlpha,
                        ),
                        dayCount: days.length,
                      )
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HourAxis(),
                    for (final day in days)
                      Expanded(child: WeekDayColumn(day: day)),
                  ],
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

class _HourAxis extends StatelessWidget {
  const _HourAxis();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final style = theme.textCaptionMono.copyWith(
      color: theme.colorTextSecondary,
    );
    return SizedBox(
      width: CalendarGridTokens.weekGutterWidth,
      child: Stack(
        children: [
          for (var hour = 1; hour < _hoursPerDay; hour++)
            Positioned(
              top: hour * CalendarGridTokens.weekHourHeight,
              right: theme.spacingSm,
              child: FractionalTranslation(
                translation: const Offset(0, -.5),
                child: Text(
                  timelineClock(context, TimeOfDay(hour: hour, minute: 0)),
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The faint grid behind the week: a line per hour and a slightly stronger
/// one per day, across the day columns (not the hour axis).
class _GridLines extends CustomPainter {
  const _GridLines({
    required this.hour,
    required this.day,
    required this.dayCount,
  });

  final Color hour;
  final Color day;
  final int dayCount;

  @override
  void paint(Canvas canvas, Size size) {
    const left = CalendarGridTokens.weekGutterWidth;
    final hourPaint = Paint()
      ..color = hour
      ..strokeWidth = AppHairline.width;
    for (var h = 1; h < _hoursPerDay; h++) {
      final y = h * CalendarGridTokens.weekHourHeight;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), hourPaint);
    }
    final dayPaint = Paint()
      ..color = day
      ..strokeWidth = AppHairline.width;
    final dayWidth = (size.width - left) / dayCount;
    for (var d = 0; d < dayCount; d++) {
      final x = left + d * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dayPaint);
    }
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_GridLines old) =>
      old.hour != hour || old.day != day || old.dayCount != dayCount;
}
