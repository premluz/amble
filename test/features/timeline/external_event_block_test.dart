import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/external_event_block.dart';
import 'package:amble/shared/models/external_calendar_event.dart';

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              ExternalEventBlock(
                theme: AmbleTheme.light,
                event: event,
                rangeStart: rangeStart,
                pixelsPerMinute: pixelsPerMinute,
                left: 56,
                width: 300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('positioned at the event\'s strict time, no offset', (
    tester,
  ) async {
    await pump(tester);
    final positioned = tester.widget<Positioned>(find.byType(Positioned));

    // (07:00 - 06:00) * 1.5 = 90.0.
    expect(positioned.top, 90.0);
    expect(positioned.left, 56.0);
    expect(positioned.width, 300.0);
    // (08:00 - 07:00) * 1.5 = 90.0.
    expect(positioned.height, 90.0);
  });

  testWidgets('renders the event title on the block', (tester) async {
    await pump(tester);
    expect(find.text('Dentist'), findsOneWidget);
  });

  testWidgets('shows the event\'s start-end time on the block itself, not '
      'only inside the tap sheet', (tester) async {
    await pump(tester);
    expect(find.textContaining('7:00'), findsOneWidget);
  });

  // Regression test for a real bug, reported directly: "but same line" —
  // a short event's duration-based height could land shorter than what its
  // OWN two text lines (time + title) need, and a Positioned box shorter
  // than its content doesn't grow to fit it, so the two lines rendered
  // squeezed together instead of genuinely stacked. See
  // externalEventBlockMinHeight's own doc comment for the fix.
  testWidgets(
    'a very short event\'s rendered height is still tall enough for both '
    'text lines — never shorter than externalEventBlockMinHeight',
    (tester) async {
      final shortEvent = ExternalCalendarEvent(
        id: 'evt-short',
        title: 'Quick sync',
        start: DateTime(2026, 9, 2, 7),
        end: DateTime(2026, 9, 2, 7, 5), // 5 minutes.
        sourceCalendarId: 'cal-1',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                ExternalEventBlock(
                  theme: AmbleTheme.light,
                  event: shortEvent,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: 56,
                  width: 300,
                ),
              ],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      // 5 minutes * 1.5 = 7.5px real duration height — far under two text
      // lines' worth of space, so the floor must be what actually applies.
      expect(
        positioned.height,
        greaterThanOrEqualTo(externalEventBlockMinHeight(AmbleTheme.light)),
      );
      // No RenderFlex overflow — the two lines genuinely fit, not clipped.
      expect(tester.takeException(), isNull);
    },
  );

  // Regression test for a real bug, reported directly: "also inportent
  // tasks not seeing in one line.. hour with title" — List (collapsed)
  // mode's own compactText flag already exists on TaskCapsuleBlock/
  // OverlapClusterBlock (their rows go one-line in that mode), but this
  // block had no such branch at all and always stacked time/title onto two
  // Text widgets regardless of the caller's mode.
  testWidgets(
    'compactText: true renders the time and title on ONE line, no stacked '
    'Column — matching TaskCapsuleBlock/OverlapClusterBlock\'s own List '
    'mode layout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                ExternalEventBlock(
                  theme: AmbleTheme.light,
                  event: event,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: 56,
                  width: 300,
                  compactText: true,
                ),
              ],
            ),
          ),
        ),
      );

      // One Text.rich carrying both spans, not two separate Text widgets —
      // the stacked (non-compact) layout renders two.
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ExternalEventBlock),
          matching: find.byType(Text),
        ),
      );
      expect(texts.length, 1);
      final fullText = texts.single.textSpan!.toPlainText();
      expect(fullText, contains('7:00'));
      expect(fullText, contains('Dentist'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping the block shows a read-only info sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();

    // Title appears twice once the sheet is open: once on the block behind
    // it, once in the sheet itself.
    expect(find.text('Dentist'), findsNWidgets(2));
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets(
    'the info sheet has no edit/complete/delete affordances — a plain '
    'read-only Column of Text, nothing interactive beyond dismissal',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    },
  );
}
