import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/tracked_behavior/tracked_calendar_period.dart';
import 'package:amble/features/tracked_behavior/tracked_period_calendar.dart';
import 'package:amble/shared/models/tracked_behavior_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2025, 9, 29);

  test('period labels and bounds follow the selected calendar mode', () {
    expect(
      TrackedCalendarPeriod.label(monday, TrackedBehaviorViewMode.weekly),
      'Mon 29 Sep – Sun 5 Oct',
    );
    expect(
      TrackedCalendarPeriod.start(monday, TrackedBehaviorViewMode.weekly),
      monday,
    );
    expect(
      TrackedCalendarPeriod.end(monday, TrackedBehaviorViewMode.weekly),
      DateTime(2025, 10, 5),
    );
    expect(
      TrackedCalendarPeriod.label(
        DateTime(2025, 12, 29),
        TrackedBehaviorViewMode.weekly,
      ),
      'Mon 29 Dec 2025 – Sun 4 Jan 2026',
    );

    expect(
      TrackedCalendarPeriod.label(monday, TrackedBehaviorViewMode.monthly),
      'September',
    );
    expect(
      TrackedCalendarPeriod.start(monday, TrackedBehaviorViewMode.monthly),
      DateTime(2025, 9),
    );
    expect(
      TrackedCalendarPeriod.end(monday, TrackedBehaviorViewMode.monthly),
      DateTime(2025, 9, 30),
    );

    expect(
      TrackedCalendarPeriod.label(monday, TrackedBehaviorViewMode.sixMonthly),
      'July – December 2025',
    );
    expect(
      TrackedCalendarPeriod.start(monday, TrackedBehaviorViewMode.sixMonthly),
      DateTime(2025, 7),
    );
    expect(
      TrackedCalendarPeriod.end(monday, TrackedBehaviorViewMode.sixMonthly),
      DateTime(2025, 12, 31),
    );
    expect(
      TrackedCalendarPeriod.label(
        DateTime(2026, 2),
        TrackedBehaviorViewMode.sixMonthly,
      ),
      'January – June 2026',
    );
  });

  test('period stepping advances and returns to aligned boundaries', () {
    expect(
      TrackedCalendarPeriod.shift(monday, TrackedBehaviorViewMode.weekly, 1),
      DateTime(2025, 10, 6),
    );
    expect(
      TrackedCalendarPeriod.shift(monday, TrackedBehaviorViewMode.monthly, 1),
      DateTime(2025, 10),
    );
    expect(
      TrackedCalendarPeriod.shift(
        DateTime(2025, 8, 20),
        TrackedBehaviorViewMode.sixMonthly,
        1,
      ),
      DateTime(2026, 1),
    );
    expect(
      () => TrackedCalendarPeriod.shift(
        monday,
        TrackedBehaviorViewMode.weekly,
        0,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('a left swipe advances the header and the displayed period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TrackedPeriodCalendar(
            viewMode: TrackedBehaviorViewMode.weekly,
            initialDate: monday,
            bodyBuilder: (context, date) =>
                Center(child: Text('${date.year}-${date.month}-${date.day}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon 29 Sep – Sun 5 Oct'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Mon 29 Sep – Sun 5 Oct'));
    expect(label.style, AmbleTheme.light.textBody);
    final labelTop = tester.getTopLeft(find.text('Mon 29 Sep – Sun 5 Oct')).dy;
    expect(find.text('2025-9-29'), findsOneWidget);

    await tester.drag(find.text('2025-9-29'), const Offset(-64, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mon 6 Oct – Sun 12 Oct'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Mon 6 Oct – Sun 12 Oct')).dy, labelTop);
    expect(find.text('2025-10-6'), findsOneWidget);
  });

  testWidgets(
    'the caption stays left aligned and Today returns to this period',
    (tester) async {
      final today = DateTime.now();
      final todayLabel = TrackedCalendarPeriod.label(
        today,
        TrackedBehaviorViewMode.weekly,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TrackedPeriodCalendar(
              viewMode: TrackedBehaviorViewMode.weekly,
              initialDate: today,
              bodyBuilder: (context, date) =>
                  Center(child: Text('${date.year}-${date.month}-${date.day}')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heading = find.text(todayLabel);
      expect(heading, findsOneWidget);
      expect(
        tester.getTopLeft(heading).dx,
        AmbleTheme.light.spacingScreenPadding,
      );
      expect(tester.widget<Text>(heading).textAlign, TextAlign.start);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.text('Today'),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );

      await tester.drag(
        find.text('${today.year}-${today.month}-${today.day}'),
        const Offset(-64, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.text('Today'),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isFalse,
      );
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text(todayLabel), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.text('Today'),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
    },
  );
}
