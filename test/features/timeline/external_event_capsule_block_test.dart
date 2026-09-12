import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';

/// Covers the Spatial Task View + List view's real-capsule-pill format for
/// external/imported calendar events — reversed 2026-09-06 (confirmed
/// directly: "the importend tasks sohuld also be same format as amble
/// tasks... pill in zones and text outside same positioned x and same
/// format on task view and list view"). Zone view's own `ExternalEventBlock`
/// is untouched and unrelated — see `external_event_block_test.dart`.
void main() {
  const pixelsPerMinute = 1.5;
  final rangeStart = DateTime(2026, 9, 2, 6); // 06:00
  final event = ExternalCalendarEvent(
    id: 'evt-1',
    title: 'Dentist',
    start: DateTime(2026, 9, 2, 7), // 07:00
    end: DateTime(2026, 9, 2, 8), // 08:00
    sourceCalendarId: 'cal-1',
    sourceCalendarName: 'Personal',
  );

  Future<void> pump(
    WidgetTester tester, {
    bool compactText = false,
    bool durationVisible = true,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              ExternalEventCapsuleBlock(
                theme: AmbleTheme.light,
                event: event,
                rangeStart: rangeStart,
                pixelsPerMinute: pixelsPerMinute,
                left: 56,
                columnOffset: 0,
                textColumnLeft: 96,
                textColumnRight: 0,
                compactText: compactText,
                durationVisible: durationVisible,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Asserts RENDERED geometry, not `Positioned` widget properties. The
  // earlier version of this test checked `Positioned.left` values and so
  // could not see that the whole subtree hung off the wrong origin — the
  // rail read as correct while every title sat 56px (the hour gutter's
  // width) left of where native task titles are. Reported directly from a
  // screenshot: "importent tasks are not lined up with native tasks".
  testWidgets('the rail renders at `left`, and the title at '
      '`left + textColumnLeft` — absolute on-screen positions, matching a '
      'real task\'s split layout origin', (tester) async {
    // durationVisible: false so the time/duration columns collapse and the
    // title itself starts the text column — making its x directly
    // comparable to `left + textColumnLeft`.
    await pump(tester, durationVisible: false);

    // The rail's own box starts at `left`; its icon is centred inside a
    // badge-width box, so the box's left edge is what must equal `left`.
    final railBoxX = tester
        .getTopLeft(
          find
              .ancestor(
                of: find.byIcon(Icons.calendar_today_outlined),
                matching: find.byType(SizedBox),
              )
              .first,
        )
        .dx;
    final titleX = tester.getTopLeft(find.text('Dentist')).dx;

    expect(railBoxX, 56.0, reason: 'rail sits at the day column\'s left edge');
    expect(
      titleX,
      56.0 + 96.0,
      reason:
          'the title must clear the gutter too — `left + textColumnLeft`, '
          'the same absolute x a native task title resolves to',
    );
  });

  testWidgets(
    'renders the event title and time, Task view\'s fixed-column format '
    '(unspaced dash) by default',
    (tester) async {
      await pump(tester);

      expect(find.text('Dentist'), findsOneWidget);
      expect(find.textContaining('7:00'), findsOneWidget);
    },
  );

  // Reversed — requested directly: "no time no duration would apply to
  // imported tasks." List view now never shows an imported event's time
  // or duration at all, regardless of `durationVisible` — unlike Task
  // view (compactText: false), which keeps showing it by default.
  testWidgets('compactText hides the time entirely — List view never shows an '
      'imported event\'s time or duration', (tester) async {
    await pump(tester, compactText: true);

    expect(find.textContaining('7:00'), findsNothing);
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final combined = richTexts.map((rt) => rt.text.toPlainText()).join(' | ');
    expect(combined, contains('Dentist'));
  });

  testWidgets(
    'compactText with durationVisible: true still hides the time — the '
    'List-view override is absolute, not just the default',
    (tester) async {
      await pump(tester, compactText: true, durationVisible: true);

      expect(find.textContaining('7:00'), findsNothing);
    },
  );

  testWidgets('tapping the pill or the text fires onTap', (tester) async {
    var tapped = 0;
    await pump(tester, onTap: () => tapped++);

    await tester.tap(find.byType(GestureDetector).first);
    expect(tapped, 1);
  });

  testWidgets('renders a calendar icon on the rail (the visual distinction '
      'from a real task\'s category icon)', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });

  testWidgets(
    'no interactive affordances beyond the tap — no checkbox, no resize '
    'handle, no drag: this stays look-only',
    (tester) async {
      await pump(tester);
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // Reported directly: "no time start end for importend tasks, like native
  // amble tasks, and aligned x position to all other names."
  testWidgets(
    'durationVisible: false hides the whole time column, title takes the '
    'full width — matching a real task\'s own TaskCapsuleTextRow behavior',
    (tester) async {
      await pump(tester, durationVisible: false);

      expect(find.textContaining('7:00'), findsNothing);
      expect(find.text('Dentist'), findsOneWidget);
    },
  );

  testWidgets(
    'the title\'s rendered x matches a real TaskCapsuleTextRow\'s title x '
    'at the same textColumnLeft and durationVisible — genuine cross-widget '
    'alignment, not just equal input values',
    (tester) async {
      const textColumnLeft = 96.0;
      const dayColumnLeft = 56.0; // the hour gutter's own width
      final task = Task.create(
        title: 'Stretching',
        scheduledAt: DateTime(2026, 9, 2, 9),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.health,
      );

      // Replicates `_DraggableTaskBlock._buildSplit`'s REAL structure: an
      // outer box at the day column's left edge, with the text column
      // positioned relative to it. Positioning the text row at a bare
      // `textColumnLeft` here (as this test originally did) quietly moved
      // the native side to the same wrong origin the widget under test
      // had, so the two agreed while BOTH were 56px off — which is how the
      // misalignment shipped despite this test passing.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: dayColumnLeft,
                  right: 0,
                  // The native path's outer box carries an explicit height
                  // (`rowHeight`); without one the inner Stack has nothing
                  // to lay out against.
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: textColumnLeft,
                        right: 0,
                        child: TaskCapsuleTextRow(
                          task: task,
                          timeColumnWidth: taskTimeColumnWidth(
                            AmbleTheme.light,
                          ),
                          durationColumnWidth: taskDurationColumnWidth(
                            AmbleTheme.light,
                          ),
                          durationVisible: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final taskTitleX = tester.getTopLeft(find.text('Stretching')).dx;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                ExternalEventCapsuleBlock(
                  theme: AmbleTheme.light,
                  event: event,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: 56,
                  columnOffset: 0,
                  textColumnLeft: textColumnLeft,
                  textColumnRight: 0,
                  durationVisible: false,
                ),
              ],
            ),
          ),
        ),
      );
      final eventTitleX = tester.getTopLeft(find.text('Dentist')).dx;

      expect(eventTitleX, taskTitleX);
    },
  );

  // Reported directly from a screenshot: "text not aligned wit hnative
  // tasks. all tasks text should be aligned to same x" — an event sharing
  // a lane group with an overlapping task landed in `column: 1`, and an
  // earlier version baked that lane offset straight into `left`, shifting
  // the WHOLE box (rail and text alike) right by a full pill width. A
  // real task's own text column stays fixed regardless of its pill's
  // lane — only the rail moves — so an event in a deeper lane must match.
  testWidgets(
    'the title\'s x stays fixed at `left + textColumnLeft` regardless of '
    '`columnOffset` — only the rail moves when an event lands in a '
    'deeper lane',
    (tester) async {
      Future<double> titleXFor(double columnOffset) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: Stack(
                children: [
                  ExternalEventCapsuleBlock(
                    theme: AmbleTheme.light,
                    event: event,
                    rangeStart: rangeStart,
                    pixelsPerMinute: pixelsPerMinute,
                    left: 56,
                    columnOffset: columnOffset,
                    textColumnLeft: 96,
                    textColumnRight: 0,
                    durationVisible: false,
                  ),
                ],
              ),
            ),
          ),
        );
        return tester.getTopLeft(find.text('Dentist')).dx;
      }

      final laneZeroX = await titleXFor(0);
      final laneOneX = await titleXFor(120); // one pill-width+gap over

      expect(laneOneX, laneZeroX);
    },
  );
}
