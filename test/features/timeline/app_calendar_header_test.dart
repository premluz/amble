import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';

/// Covers `AppCalendarHeader` in isolation — the shared top calendar bar
/// (month stepper, "jump to today" button, sync placeholder, Edit Mode
/// pen-icon toggle, fixed Sun-Sat week grid) introduced 2026-09-12 to
/// replace the old bottom `DayStrip`'s day-navigation half. See
/// docs/DECISIONS.md's matching entry for the full confirmed scope.
void main() {
  Future<ProviderContainer> pumpHeader(
    WidgetTester tester, {
    DateTime? initialDate,
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (initialDate != null)
            selectedDateProvider.overrideWith(
              () => _FixedSelectedDate(initialDate),
            ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const Scaffold(body: AppCalendarHeader()),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('renders a full Sun-Sat week grid — 7 day cells, one per '
      'weekday header letter', (tester) async {
    await pumpHeader(tester);

    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  testWidgets('the today button always shows the real current day-of-month, '
      'not a fixed placeholder', (tester) async {
    await pumpHeader(tester);

    expect(find.text('${DateTime.now().day}'), findsWidgets);
  });

  testWidgets('tapping the today button jumps the selected date back to '
      'today', (tester) async {
    final aWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final container = await pumpHeader(tester, initialDate: aWeekAgo);
    expect(container.read(selectedDateProvider), _dateOnly(aWeekAgo));

    await tester.tap(find.byTooltip('Today'));
    await tester.pump();

    expect(container.read(selectedDateProvider), _dateOnly(DateTime.now()));
  });

  testWidgets('the sync icon is a placeholder — tapping it does nothing, '
      'no callback wired yet', (tester) async {
    final container = await pumpHeader(tester);
    final before = container.read(selectedDateProvider);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pump();

    expect(container.read(selectedDateProvider), before);
    expect(container.read(editModeEnabledProvider), isFalse);
  });

  testWidgets('the Edit Mode control is a pen icon, and tapping it toggles '
      'editModeEnabledProvider', (tester) async {
    final container = await pumpHeader(tester);
    expect(container.read(editModeEnabledProvider), isFalse);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();

    expect(container.read(editModeEnabledProvider), isTrue);
    expect(find.byTooltip('Done'), findsOneWidget);
  });

  testWidgets('tapping the month name steps the visible week forward by 7 '
      'days', (tester) async {
    final anchor = DateTime(2026, 9, 10);
    final container = await pumpHeader(tester, initialDate: anchor);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();

    expect(
      container.read(selectedDateProvider),
      _dateOnly(anchor.add(const Duration(days: 7))),
    );
  });

  testWidgets('a horizontal swipe on the week grid steps the visible week '
      'by 7 days', (tester) async {
    final anchor = DateTime(2026, 9, 10);
    final container = await pumpHeader(tester, initialDate: anchor);

    final weekRowSwipeArea = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector && widget.onHorizontalDragEnd != null,
    );
    await tester.fling(weekRowSwipeArea, const Offset(300, 0), 800);
    await tester.pump();

    final after = container.read(selectedDateProvider);
    expect(
      after.difference(anchor).inDays.abs(),
      7,
      reason:
          'a completed horizontal swipe must move the week by exactly '
          'one full week either direction',
    );
  });

  testWidgets('tapping a day cell in the week grid selects that day', (
    tester,
  ) async {
    final anchor = DateTime(2026, 9, 10); // a Thursday
    final container = await pumpHeader(tester, initialDate: anchor);

    // The grid's Sunday cell for this week is 2026-09-06.
    await tester.tap(find.text('6'));
    await tester.pump();

    expect(container.read(selectedDateProvider), DateTime(2026, 9, 6));
  });
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _FixedSelectedDate extends SelectedDate {
  _FixedSelectedDate(this._initial);

  final DateTime _initial;

  @override
  DateTime build() => _dateOnly(_initial);
}
