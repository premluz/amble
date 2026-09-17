import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/shared/providers/preferences_providers.dart';

/// Covers `AppCalendarHeader` in isolation — the shared top calendar bar
/// (month stepper, "jump to today" button, sync placeholder, Edit Mode
/// pen-icon toggle, fixed Sun-Sat week grid) introduced 2026-09-12 to
/// replace the old bottom `DayStrip`'s day-navigation half. See
/// docs/DECISIONS.md's matching entry for the full confirmed scope.
void main() {
  Future<ProviderContainer> pumpHeader(
    WidgetTester tester, {
    DateTime? initialDate,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (initialDate != null)
            selectedDateProvider.overrideWith(
              () => _FixedSelectedDate(initialDate),
            ),
          // AppCalendarHeader now reads this directly (its own switcher
          // button, added when Task view/Timeline merged into one nav
          // item) — this test has no Hive box set up at all, so without
          // an override the real notifier throws trying to read
          // preferencesRepositoryProvider. A fixed, in-memory stand-in
          // keeps this suite's existing widget-isolation scope (no real
          // persistence needed for what these tests actually check).
          zoneViewEnabledSettingProvider.overrideWith(
            () => _FixedZoneViewEnabled(false),
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
              navigatorObservers: navigatorObservers,
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

  testWidgets('the spatial/Zone view switcher reflects the current setting and '
      'tapping it flips zoneViewEnabledSettingProvider', (tester) async {
    final container = await pumpHeader(tester);
    expect(container.read(zoneViewEnabledSettingProvider), isFalse);
    expect(find.byTooltip('Switch to Timeline'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to Timeline'));
    await tester.pump();

    expect(container.read(zoneViewEnabledSettingProvider), isTrue);
    expect(find.byTooltip('Switch to Task view'), findsOneWidget);
  });

  testWidgets(
    'the Edit Mode control is a pen icon, and tapping it opens the merged '
    'Edit screen rather than toggling editModeEnabledProvider in place',
    (tester) async {
      // **2026-09-17** — was a direct in-place toggle; now opens
      // `ZoneGridScreen` (Tasks/Zones tabs), requested directly: "one
      // entry point instead of 2 in the header." `editModeEnabledProvider`
      // itself is untouched by THIS tap — it's `ZoneGridScreen`'s own
      // `_syncEditMode` that turns Edit Mode on once that screen mounts
      // (covered by `zone_grid_edit_screen_merge_test.dart`, which has
      // the real Hive setup this isolated suite intentionally doesn't).
      final pushedRoutes = <Route<void>>[];
      final observer = _RoutePushObserver(pushedRoutes.add);
      await pumpHeader(tester, navigatorObservers: [observer]);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      // The pushed `ZoneGridScreen` genuinely fails to BUILD here — this
      // suite has no Hive boxes set up at all (by design, per its own
      // "in isolation" doc comment), and that screen's embedded
      // TimelineScreen needs real repositories. `didPush` (checked below)
      // already fires synchronously as part of `Navigator.push`, before
      // that failed build — this test only needs to know a route WAS
      // pushed, not that it rendered, so the expected build error is
      // consumed rather than left to fail the test.
      tester.takeException();

      expect(
        pushedRoutes.whereType<MaterialPageRoute<void>>(),
        isNotEmpty,
        reason:
            'tapping the pen icon must push a new route (the merged '
            'Edit screen), not just flip a provider in place',
      );
    },
  );

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

  // Requested directly: "top calendar (week view) on timeline and task
  // view spatial and nonspatial smaller font. And selected should [shrink
  // too, same relative emphasis]" (confirmed via AskUserQuestion).
  testWidgets('the day-number cells use textCaption, matching the weekday '
      'letter row above them, and selected keeps only its WEIGHT '
      'difference — not a separate, larger size', (tester) async {
    await pumpHeader(tester, initialDate: DateTime(2026, 9, 6));

    final theme = AmbleTheme.light;
    // Scoped to `_WeekDayCell` specifically — a bare digit-regex match
    // also caught the "jump to today" button's own day-of-month text
    // elsewhere in the header, a DIFFERENT widget with its own unrelated
    // bold treatment.
    final dayTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_WeekDayCell',
            ),
            matching: find.textContaining(RegExp(r'^\d{1,2}$')),
          ),
        )
        .toList();

    expect(dayTexts, hasLength(7), reason: 'one cell per weekday');
    for (final text in dayTexts) {
      expect(
        text.style?.fontSize,
        theme.textCaption.fontSize,
        reason:
            'every day cell — selected or not — must be sized off '
            'textCaption, matching the "S M T W T F S" row above it',
      );
    }

    // The selected day (the 6th) still reads as selected via weight alone.
    final selectedDay = dayTexts.firstWhere((t) => t.data == '6');
    final unselectedDay = dayTexts.firstWhere((t) => t.data != '6');
    expect(selectedDay.style?.fontWeight, FontWeight.w700);
    expect(unselectedDay.style?.fontWeight, FontWeight.w500);
  });
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _FixedSelectedDate extends SelectedDate {
  _FixedSelectedDate(this._initial);

  final DateTime _initial;

  @override
  DateTime build() => _dateOnly(_initial);
}

class _FixedZoneViewEnabled extends ZoneViewEnabledSetting {
  _FixedZoneViewEnabled(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  // The real notifier's `set` persists to `preferencesRepositoryProvider`,
  // unavailable in this widget-isolation suite (no Hive box set up at
  // all) — this test only needs the in-memory state to actually flip.
  @override
  Future<void> set(bool value) async {
    state = value;
  }
}

class _RoutePushObserver extends NavigatorObserver {
  _RoutePushObserver(this.onPush);

  final void Function(Route<void>) onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPush(route as Route<void>);
  }
}
