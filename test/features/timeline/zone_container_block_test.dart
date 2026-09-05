import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  final zone = Zone.create(
    title: 'Morning ritual',
    startMinutes: 7 * 60,
    endMinutes: 12 * 60,
  );
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 230, // 3h 50m.
    categoryId: BuiltInCategoryIds.work,
  );
  final stackKey = GlobalKey();

  Future<void> pump(
    WidgetTester tester, {
    bool durationVisible = true,
    List<ExternalCalendarEvent> externalEvents = const [],
    bool showCompletionCheckbox = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: 400,
            child: ZoneContainerBlock(
              theme: AmbleTheme.light,
              zone: zone,
              tasks: [task],
              externalEvents: externalEvents,
              categoriesById: const {},
              stackAncestorKey: stackKey,
              durationVisible: durationVisible,
              showCompletionCheckbox: showCompletionCheckbox,
            ),
          ),
        ),
      ),
    );
  }

  // Regression test for a real bug, reported directly: "task name should
  // be same font size as time and duration of task in zone mode, atm in
  // list mode and task mode font is larger of time and task name" — the
  // in-container row's title used textBody while its time/duration line
  // used the smaller textCaption, unlike Task/List mode where both use
  // textBody.
  testWidgets('the task title and its time line render at the same font size', (
    tester,
  ) async {
    await pump(tester);

    final titleText = tester.widget<Text>(find.text('Deep work'));
    final timeText = tester.widget<Text>(
      find.textContaining('9:00', findRichText: false),
    );

    expect(titleText.style?.fontSize, timeText.style?.fontSize);
  });

  // Second half of the same report: Zone mode should show "start - end
  // (duration)" like Task mode, not just a bare start time.
  testWidgets(
    'shows "start - end (duration)", matching TaskCapsuleBlock\'s format',
    (tester) async {
      await pump(tester);
      expect(
        find.textContaining('9:00 AM - 12:50 PM (3h 50m)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'durationVisible: false hides the "(duration)" suffix but keeps the '
    'start - end range — matches the dev-config toggle\'s existing '
    'TaskCapsuleBlock contract',
    (tester) async {
      await pump(tester, durationVisible: false);
      expect(find.textContaining('9:00 AM - 12:50 PM'), findsOneWidget);
      expect(find.textContaining('3h 50m'), findsNothing);
    },
  );

  group('externalEvents (merged into the container\'s own row list)', () {
    // Regression coverage for a real bug, reported directly: "on zone
    // mode tasks imported should be inside zones like other task[s]" —
    // external events previously only rendered on the outer axis,
    // regardless of whether they belonged inside a zone.
    final event = ExternalCalendarEvent(
      id: 'evt-1',
      title: 'Team sync',
      start: DateTime(2026, 9, 4, 10),
      end: DateTime(2026, 9, 4, 10, 30),
      sourceCalendarId: 'cal-1',
    );

    testWidgets('a matched external event renders as its own row inside '
        'the container, alongside the zone\'s tasks', (tester) async {
      await pump(tester, externalEvents: [event]);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Team sync'), findsOneWidget);
    });

    testWidgets(
      'tapping an external event row opens the read-only info sheet',
      (tester) async {
        await pump(tester, externalEvents: [event]);

        await tester.tap(find.text('Team sync'));
        await tester.pumpAndSettle();

        // Title appears twice with the sheet open: once on the row
        // behind it, once in the sheet itself.
        expect(find.text('Team sync'), findsNWidgets(2));
      },
    );

    testWidgets('an external event row has no completion checkbox — strictly '
        'read-only, unlike a real task row', (tester) async {
      await pump(tester, externalEvents: [event]);
      // Exactly one CompletionCheckbox — the real task's — not two;
      // the external event row renders no equivalent control at all.
      expect(find.byType(CompletionCheckbox), findsOneWidget);
    });
  });

  // `ShowCompletionCheckboxSetting` — one setting across all three views.
  // This is the Zone view's own row; the other two are covered by
  // task_capsule_checkbox_test.dart and overlap_cluster_block_test.dart.
  testWidgets(
    'showCompletionCheckbox: false removes the task row\'s checkbox',
    (tester) async {
      await pump(tester);
      expect(find.byType(CompletionCheckbox), findsOneWidget);

      await pump(tester, showCompletionCheckbox: false);
      expect(find.byType(CompletionCheckbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
