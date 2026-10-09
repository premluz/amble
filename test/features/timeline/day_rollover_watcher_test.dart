import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/current_day_provider.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_date_accordion.dart';
import 'package:amble/features/timeline/day_rollover_watcher.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/features/timeline/viewed_time_provider.dart';

/// Requested directly: "when day actually changed it doesn't refresh (dot)
/// and move to the current selected day when user visits apps again on new
/// day... open always at current day and current hour in the middle."
void main() {
  final monday = DateTime(2026, 10, 5, 22);
  final tuesday = DateTime(2026, 10, 6, 8);

  group('DayRolloverWatcher', () {
    late DateTime clock;
    late ProviderContainer container;

    setUp(() {
      clock = monday;
      container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => clock)],
      );
      addTearDown(container.dispose);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DayRolloverWatcher(
              child: Consumer(
                builder: (context, ref, _) => Text(
                  '${ref.watch(selectedDateProvider).day}',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }

    testWidgets('resuming on a new day selects today and drops the '
        'remembered hour, so the day view re-centers on now', (tester) async {
      await pump(tester);
      container.read(viewedTimeProvider.notifier).set(21 * 60);
      expect(find.text('5'), findsOneWidget);

      clock = tuesday;
      await resume(tester);

      expect(find.text('6'), findsOneWidget);
      expect(container.read(currentDayProvider), DateTime(2026, 10, 6));
      expect(container.read(viewedTimeProvider), isNull);
    });

    testWidgets('resuming on the same day leaves the user where they were', (
      tester,
    ) async {
      await pump(tester);
      container
          .read(selectedDateProvider.notifier)
          .goTo(DateTime(2026, 10, 9));
      container.read(viewedTimeProvider.notifier).set(14 * 60);

      clock = monday.add(const Duration(minutes: 30));
      await resume(tester);

      expect(find.text('9'), findsOneWidget);
      expect(container.read(viewedTimeProvider), 14 * 60);
    });

    testWidgets('midnight passing while the app is open rolls over too', (
      tester,
    ) async {
      clock = DateTime(2026, 10, 5, 23, 59, 30);
      await pump(tester);

      clock = DateTime(2026, 10, 6, 0, 0, 1);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('returning to the Day screen on a new day rolls over on '
        'mount', (tester) async {
      // Both built on Monday and kept alive, as the header keeps them in
      // the app — otherwise selectedDate would simply rebuild on Tuesday
      // and this test would pass without any rollover at all.
      container.read(currentDayProvider);
      container.listen(selectedDateProvider, (_, _) {});
      clock = tuesday;

      await pump(tester);

      expect(find.text('6'), findsOneWidget);
    });
  });

  group('AppDateAccordion today dot', () {
    Future<void> pumpAccordion(WidgetTester tester, DateTime today) =>
        tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AmbleTheme.light]),
            home: Scaffold(
              body: AppDateAccordion(
                selectedDate: DateTime(2026, 10, 5),
                onDateSelected: (_) {},
                expanded: true,
                today: today,
              ),
            ),
          ),
        );

    double dotCenterX(WidgetTester tester) {
      final dot = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration! as BoxDecoration).color ==
                AmbleTheme.light.colorAccent,
      );
      expect(dot, findsOneWidget);
      return tester.getCenter(dot).dx;
    }

    testWidgets('sits under the day passed as today, and follows it', (
      tester,
    ) async {
      await pumpAccordion(tester, DateTime(2026, 10, 5));
      expect(dotCenterX(tester), tester.getCenter(find.text('5')).dx);

      await pumpAccordion(tester, DateTime(2026, 10, 6));
      expect(dotCenterX(tester), tester.getCenter(find.text('6')).dx);
    });
  });
}
