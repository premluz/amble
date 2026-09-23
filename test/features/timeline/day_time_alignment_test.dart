import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/current_time_indicator.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/features/timeline/zone_day_timeline.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 9, 23);
final _theme = AmbleTheme.light;

Widget _app(Widget child, bool use24Hour) => MaterialApp(
  theme: ThemeData(extensions: [_theme]),
  home: MediaQuery(
    data: MediaQueryData(alwaysUse24HourFormat: use24Hour),
    child: Scaffold(body: child),
  ),
);

Task _task(String title, int hour) => Task.create(
  title: title,
  scheduledAt: _day.add(Duration(hours: hour)),
  durationMinutes: 15,
  categoryId: BuiltInCategoryIds.health,
);

ExternalCalendarEvent _event(String id, int hour) => ExternalCalendarEvent(
  id: id,
  title: id,
  start: _day.add(Duration(hours: hour)),
  end: _day.add(Duration(hours: hour, minutes: 30)),
  sourceCalendarId: 'calendar',
);

Widget _list() => ZoneDayTimeline(
  tasks: [_task('Outside', 6), _task('Inside', 9)],
  zones: [
    Zone(id: 'zone', title: 'Morning', startMinutes: 480, endMinutes: 720),
  ],
  externalEvents: [_event('Inside event', 10), _event('Outside event', 13)],
  theme: _theme,
  categoryById: const {},
  selectedDate: _day,
  onTaskTap: (_) {},
  onToggleComplete: (_) {},
  devZoneTaskStartTimeVisible: true,
  devTimeRangeVisible: false,
  devDurationVisible: false,
);

void _expectTimesAligned(WidgetTester tester) {
  final labels = find.descendant(
    of: find.byType(ZoneRowTimeLabel),
    matching: find.byType(Text),
  );
  expect(labels, findsNWidgets(4));
  for (final element in labels.evaluate()) {
    final label = element.widget as Text;
    final rect = tester.getRect(find.byWidget(label));
    expect(rect.left, _theme.timelineTimeLeft);
    expect(rect.width, greaterThan(0));
    expect(label.style?.fontFamily, _theme.textCaptionMono.fontFamily);
    expect(rect.overlaps(tester.getRect(find.byType(Scaffold))), isTrue);
  }
}

void main() {
  for (final use24Hour in [false, true]) {
    testWidgets('zoned and unzoned task/event times align: 24h=$use24Hour', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_list(), use24Hour));
      await tester.pumpAndSettle();
      _expectTimesAligned(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('current time text starts on the time edge: 24h=$use24Hour', (
      tester,
    ) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _app(
          Stack(
            children: [
              CurrentTimeIndicator(
                rangeStart: now.subtract(const Duration(minutes: 1)),
                rangeEnd: now.add(const Duration(minutes: 1)),
                leftInset: _theme.timelineTimeLeft,
              ),
            ],
          ),
          use24Hour,
        ),
      );
      final text = find.descendant(
        of: find.byType(CurrentTimeIndicator),
        matching: find.byType(Text),
      );
      expect(tester.getTopLeft(text).dx, _theme.timelineTimeLeft);
    });
  }
}
