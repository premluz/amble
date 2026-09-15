import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/shared/models/external_calendar_event.dart';

/// Regression coverage for a real bug, reported directly from an annotated
/// screenshot ("text too high, should be middle"): an imported event's
/// title was top-aligned inside its own 24px dashed badge rather than
/// centred on it, so the title's centre sat a consistent 4px ABOVE the
/// icon's at every duration.
///
/// The equivalent native-task invariant lives in
/// `task_capsule_title_alignment_test.dart`; this is the imported-event
/// side of the same "title is level with its icon" rule, which the user
/// asked to be consistent across both views.
void main() {
  Future<void> pumpEvent(
    WidgetTester tester, {
    required int durationMinutes,
  }) async {
    final theme = AmbleTheme.light;
    final rangeStart = DateTime(2026, 9, 16, 8);
    final event = ExternalCalendarEvent(
      id: 'evt-1',
      title: 'Daily sync',
      start: DateTime(2026, 9, 16, 9),
      end: DateTime(2026, 9, 16, 9).add(Duration(minutes: durationMinutes)),
      sourceCalendarId: 'cal-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Stack(
            children: [
              ExternalEventCapsuleBlock(
                theme: theme,
                event: event,
                rangeStart: rangeStart,
                pixelsPerMinute: 1.5,
                left: 56,
                columnOffset: 0,
                textColumnLeft: 90,
                textColumnRight: 16,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an imported event\'s title is vertically centred on its own dashed '
    'badge icon, at every duration',
    (tester) async {
      final offsets = <int, double>{};
      for (final durationMinutes in [15, 30, 90, 180]) {
        await pumpEvent(tester, durationMinutes: durationMinutes);

        final icon = tester.getRect(find.byType(Icon));
        final title = tester.getRect(
          find.textContaining('Daily sync', findRichText: true),
        );
        offsets[durationMinutes] = title.center.dy - icon.center.dy;
      }

      for (final entry in offsets.entries) {
        expect(
          entry.value.abs(),
          lessThan(1.0),
          reason:
              'at ${entry.key}m the title centre sat ${entry.value}px from '
              'the icon centre — it must be level with the icon, not '
              'pinned to the badge\'s top (measured at -4.0 before this '
              'fix). All offsets: $offsets',
        );
      }
    },
  );

  // Requested directly: "imported tasks on timeline (spatial view) should
  // also adopt length of pill to their duration, at the moment they are
  // the same minimal size." The duration-derived height was already
  // computed for the outer box but the visible rail was pinned to a flat
  // badge size, so every imported event drew an identical 24px pill.
  testWidgets(
    'an imported event\'s rail scales with its duration, like a native '
    'task\'s does — not a fixed minimal badge',
    (tester) async {
      await pumpEvent(tester, durationMinutes: 30);
      final shortRail = tester.getRect(find.byType(DashedPillRail));

      await pumpEvent(tester, durationMinutes: 120);
      final longRail = tester.getRect(find.byType(DashedPillRail));

      expect(
        longRail.height,
        greaterThan(shortRail.height),
        reason:
            'a 120m event must draw a taller rail than a 30m one — both '
            'measured 24px before this fix (short=${shortRail.height}, '
            'long=${longRail.height})',
      );
      // 1.5 px per minute, per this test's own pumpEvent.
      expect(longRail.height, 120 * 1.5);
      expect(shortRail.height, 30 * 1.5);
    },
  );

  testWidgets(
    'a very short event still floors at the badge size rather than '
    'collapsing to nothing',
    (tester) async {
      await pumpEvent(tester, durationMinutes: 5);
      final rail = tester.getRect(find.byType(DashedPillRail));

      // 5m * 1.5 = 7.5px, well under the badge floor.
      expect(rail.height, AmbleTheme.light.sizeTaskBadge);
    },
  );

  // Pins the OTHER half of the same rule: a taller pill must not drag the
  // title down with it. The title tracks the icon, which stays at the
  // rail's own top however long the event runs.
  testWidgets(
    'a long event does not drag its title down the rail — the offset is '
    'identical to a short one\'s',
    (tester) async {
      await pumpEvent(tester, durationMinutes: 15);
      final shortIcon = tester.getRect(find.byType(Icon));
      final shortTitle = tester.getRect(
        find.textContaining('Daily sync', findRichText: true),
      );
      final shortOffset = shortTitle.center.dy - shortIcon.center.dy;

      await pumpEvent(tester, durationMinutes: 240);
      final longIcon = tester.getRect(find.byType(Icon));
      final longTitle = tester.getRect(
        find.textContaining('Daily sync', findRichText: true),
      );
      final longOffset = longTitle.center.dy - longIcon.center.dy;

      expect(longOffset, shortOffset);
    },
  );
}
