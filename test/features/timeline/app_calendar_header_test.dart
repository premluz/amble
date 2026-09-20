// The utility-icon-row tests below are commented out rather than deleted,
// matching how `AppCalendarHeader` itself keeps that row commented — see
// the block comment above those tests. These ignores cover the imports
// and helpers only those tests use, so restoring them is a single
// uncomment on both sides. Remove this line if they are ever genuinely
// deleted.
// ignore_for_file: unused_import, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/shared/providers/preferences_providers.dart';

/// Covers `AppCalendarHeader` in isolation — the shared top calendar bar
/// ("jump to today" button, sync placeholder, Edit Mode pen-icon toggle,
/// and the [AppDateAccordion] date label + collapsible Sun-Sat week grid)
/// introduced 2026-09-12 to replace the old bottom `DayStrip`'s
/// day-navigation half. See docs/DECISIONS.md's matching entry for the
/// full confirmed scope, and `AppDateAccordion`'s own doc comment for the
/// 2026-09-20 accordion behaviour (collapsed by default; the date
/// label's own tap now toggles it, rather than stepping the week).
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

  testWidgets(
    'the week grid is COLLAPSED by default — no weekday letters until '
    'the date label is tapped',
    (tester) async {
      await pumpHeader(tester);

      // "Wed"/"Sep" etc. appear in the collapsed date LABEL itself, so
      // this checks for the week-strip's own column-header row, which
      // only exists once expanded.
      expect(find.text('M'), findsNothing);
    },
  );

  testWidgets('tapping the date label reveals a full Sun-Sat week grid — 7 day '
      'cells, one per weekday header letter', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  // **2026-09-20 — commented out alongside the widgets they cover.** The
  // header's whole utility icon row (Today / Sync / zone-view switcher /
  // Edit) is hidden — requested directly: "hide top buttons 20, edit
  // sync, view change, since added them at the bottom / keep for now but
  // remove from view / comment out," since `AppBottomDock` now carries
  // equivalents. These tests are kept in the same commented-not-deleted
  // shape as the widgets themselves, so restoring the row means
  // uncommenting both sides together.
  //
  // testWidgets('the today button always shows the real current '
  //     'day-of-month, not a fixed placeholder', (tester) async {
  //   await pumpHeader(tester);
  //
  //   expect(find.text('${DateTime.now().day}'), findsWidgets);
  // });
  //
  // testWidgets('tapping the today button jumps the selected date back to '
  //     'today', (tester) async {
  //   final aWeekAgo = DateTime.now().subtract(const Duration(days: 7));
  //   final container = await pumpHeader(tester, initialDate: aWeekAgo);
  //   expect(container.read(selectedDateProvider), _dateOnly(aWeekAgo));
  //
  //   await tester.tap(find.byTooltip('Today'));
  //   await tester.pump();
  //
  //   expect(container.read(selectedDateProvider), _dateOnly(DateTime.now()));
  // });
  //
  // testWidgets('the sync icon is a placeholder — tapping it does nothing, '
  //     'no callback wired yet', (tester) async {
  //   final container = await pumpHeader(tester);
  //   final before = container.read(selectedDateProvider);
  //
  //   await tester.tap(find.byTooltip('Sync'));
  //   await tester.pump();
  //
  //   expect(container.read(selectedDateProvider), before);
  //   expect(container.read(editModeEnabledProvider), isFalse);
  // });
  //
  // testWidgets('the spatial/Zone view switcher reflects the current '
  //     'setting and tapping it flips zoneViewEnabledSettingProvider',
  //     (tester) async {
  //   final container = await pumpHeader(tester);
  //   expect(container.read(zoneViewEnabledSettingProvider), isFalse);
  //   expect(find.byTooltip('Switch to Timeline'), findsOneWidget);
  //
  //   await tester.tap(find.byTooltip('Switch to Timeline'));
  //   await tester.pump();
  //
  //   expect(container.read(zoneViewEnabledSettingProvider), isTrue);
  //   expect(find.byTooltip('Switch to Task view'), findsOneWidget);
  // });

  // Commented out alongside the hidden utility icon row — see the block
  // of commented tests above for the full reasoning. `AppBottomDock`'s
  // own Edit button now covers this entry point.
  //
  // testWidgets(
  //   'the Edit Mode control is a pen icon, and tapping it opens the '
  //   'merged Edit screen rather than toggling editModeEnabledProvider '
  //   'in place',
  //   (tester) async {
  //     final pushedRoutes = <Route<void>>[];
  //     final observer = _RoutePushObserver(pushedRoutes.add);
  //     await pumpHeader(tester, navigatorObservers: [observer]);
  //     expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  //
  //     await tester.tap(find.byTooltip('Edit'));
  //     await tester.pump();
  //     // The pushed `ZoneGridScreen` genuinely fails to BUILD here —
  //     // this suite has no Hive boxes set up at all (by design), and
  //     // that screen's embedded TimelineScreen needs real
  //     // repositories. `didPush` already fires synchronously as part
  //     // of `Navigator.push`, before that failed build.
  //     tester.takeException();
  //
  //     expect(
  //       pushedRoutes.whereType<MaterialPageRoute<void>>(),
  //       isNotEmpty,
  //       reason:
  //           'tapping the pen icon must push a new route (the merged '
  //           'Edit screen), not just flip a provider in place',
  //     );
  //   },
  // );

  // **2026-09-20 — reversed.** The date label's tap now toggles the
  // accordion open/shut (see `AppDateAccordion`'s own doc comment on
  // why) — it no longer steps the week. That job moved entirely onto
  // the horizontal swipe below, which is still bidirectional and needs
  // the strip expanded first to have anything to swipe.
  testWidgets(
    'tapping the date label toggles the week strip rather than stepping '
    'the week',
    (tester) async {
      final anchor = DateTime(2026, 9, 10);
      final container = await pumpHeader(tester, initialDate: anchor);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pump();

      expect(
        container.read(selectedDateProvider),
        _dateOnly(anchor),
        reason: 'the date label tap must only expand/collapse, never move',
      );
      expect(find.text('M'), findsOneWidget, reason: 'now expanded');
    },
  );

  testWidgets(
    'a horizontal swipe on the EXPANDED week grid steps the visible week '
    'by 7 days',
    (tester) async {
      final anchor = DateTime(2026, 9, 10);
      final container = await pumpHeader(tester, initialDate: anchor);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

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
    },
  );

  testWidgets('tapping a day cell in the EXPANDED week grid selects that day', (
    tester,
  ) async {
    final anchor = DateTime(2026, 9, 10); // a Thursday
    final container = await pumpHeader(tester, initialDate: anchor);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

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
