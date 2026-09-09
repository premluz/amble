import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/zone_day_timeline.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Covers [ZoneDayTimeline.onZoneResize]/[ZoneDayTimeline.onZoneMove]'s
/// own callback contract directly — driven at this widget's level (not
/// through the full `TimelineScreen`), same pump pattern
/// `zone_day_timeline_position_test.dart` already established, since
/// neither callback needs Riverpod: the ACTUAL cascade computation and
/// commit live in `TimelineScreen`'s `_commitZoneCascade` helper (covered
/// separately by `zone_cascade_reschedule_test.dart`'s pure-math tests
/// and `zone_providers_test.dart`'s `commitZoneCascade` provider tests) —
/// this file only proves the widget reports the right
/// (zoneId, originalStart, newStart, newEnd) tuple for each gesture.
void main() {
  const pixelsPerMinute = 3.0;
  final day = DateTime(2026, 9, 2);
  final zone = Zone(
    id: 'z1',
    title: 'Morning ritual',
    startMinutes: 7 * 60,
    endMinutes: 8 * 60,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool editModeEnabled,
    void Function(String, int, int, int)? onZoneResize,
    void Function(String, int, int, int)? onZoneMove,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: ZoneDayTimeline(
            tasks: const <Task>[],
            zones: [zone],
            theme: AmbleTheme.light,
            categoryById: const <String, Category>{},
            selectedDate: day,
            pixelsPerMinute: pixelsPerMinute,
            onTaskTap: (_) {},
            onToggleComplete: (_) {},
            onReassign: (task, zoneId, scheduledAt) async {},
            editModeEnabled: editModeEnabled,
            onZoneResize: onZoneResize,
            onZoneMove: onZoneMove,
          ),
        ),
      ),
    );
    // NOT pumpAndSettle: EditModeWiggle runs a perpetually-repeating
    // animation the instant editModeEnabled is true, which never
    // settles — see edit_mode_wiggle_test.dart's own established pattern
    // and multi_task_selection_test.dart's pumpTimeline for the same fix.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // ZoneDayTimeline auto-scrolls to center on the CURRENT real hour on
    // mount (`_scrollToCurrentHourCentered`) — this test's zone (07:00)
    // is very likely off whatever hour the suite happens to run at, so
    // every drag target inside it needs scrolling into view first.
    await tester.ensureVisible(find.text('Morning ritual (1h)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'no resize handles or move gesture are reachable outside Edit Mode',
    (tester) async {
      var resizeCalled = false;
      var moveCalled = false;
      await pump(
        tester,
        editModeEnabled: false,
        onZoneResize: (_, _, _, _) => resizeCalled = true,
        onZoneMove: (_, _, _, _) => moveCalled = true,
      );

      expect(find.byType(ResizeHandle), findsNothing);

      // The header text is still present (it's just a label outside Edit
      // Mode), but dragging it must not fire the move callback.
      await tester.drag(find.text('Morning ritual (1h)'), const Offset(0, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(resizeCalled, isFalse);
      expect(moveCalled, isFalse);
    },
  );

  testWidgets(
    'dragging the bottom resize handle later reports the SAME start and '
    'a grown end, snapped to 5 minutes',
    (tester) async {
      String? reportedZoneId;
      int? reportedOriginalStart;
      int? reportedNewStart;
      int? reportedNewEnd;
      await pump(
        tester,
        editModeEnabled: true,
        onZoneResize: (zoneId, originalStart, newStart, newEnd) {
          reportedZoneId = zoneId;
          reportedOriginalStart = originalStart;
          reportedNewStart = newStart;
          reportedNewEnd = newEnd;
        },
      );

      final handles = find.byType(ResizeHandle);
      expect(handles, findsNWidgets(2));
      // Bottom handle is the second one built (top, then bottom — see
      // ZoneContainerBlock's own construction order).
      await tester.drag(handles.last, const Offset(0, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(reportedZoneId, zone.id);
      expect(reportedOriginalStart, zone.startMinutes);
      expect(reportedNewStart, zone.startMinutes);
      // Not an exact expected offset: `tester.drag()` delivers its total
      // delta across several synthetic move events, and the very first
      // one is partially consumed as gesture-arena "slop" before the
      // recognizer accepts the drag — a real Flutter test-harness detail
      // unrelated to this feature's own contract (see
      // multi_task_group_move_test.dart's own comment on the identical
      // behavior for task drags). What actually matters here: the end
      // grew (never the start), by a positive, 5-minute-snapped amount.
      expect(reportedNewEnd, isNot(zone.endMinutes));
      expect(reportedNewEnd! > zone.endMinutes, isTrue);
      expect((reportedNewEnd! - zone.endMinutes) % 5, 0);
    },
  );

  testWidgets(
    'dragging the top resize handle earlier reports a SHRUNK start and '
    'the same end',
    (tester) async {
      String? reportedZoneId;
      int? reportedNewStart;
      int? reportedNewEnd;
      await pump(
        tester,
        editModeEnabled: true,
        onZoneResize: (zoneId, originalStart, newStart, newEnd) {
          reportedZoneId = zoneId;
          reportedNewStart = newStart;
          reportedNewEnd = newEnd;
        },
      );

      final handles = find.byType(ResizeHandle);
      // The top handle sits just ABOVE the container's own top edge —
      // scrolling the header (further down, inside the container) into
      // view doesn't guarantee this handle clears the viewport's own
      // edge too, so it needs its own ensureVisible.
      await tester.ensureVisible(handles.first);
      await tester.pump();
      await tester.drag(handles.first, const Offset(0, -30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(reportedZoneId, zone.id);
      expect(reportedNewEnd, zone.endMinutes);
      // Not an exact expected offset — see the bottom-handle test's own
      // comment on why `tester.drag()` doesn't reliably deliver its full
      // requested pixel distance. What matters: the start shrank (moved
      // earlier), by a 5-minute-snapped amount.
      expect(reportedNewStart! < zone.startMinutes, isTrue);
      expect((zone.startMinutes - reportedNewStart!) % 5, 0);
    },
  );

  testWidgets(
    'dragging the header (Edit Mode on) reports both edges shifted by '
    'the SAME delta, preserving duration',
    (tester) async {
      String? reportedZoneId;
      int? reportedOriginalStart;
      int? reportedNewStart;
      int? reportedNewEnd;
      await pump(
        tester,
        editModeEnabled: true,
        onZoneMove: (zoneId, originalStart, newStart, newEnd) {
          reportedZoneId = zoneId;
          reportedOriginalStart = originalStart;
          reportedNewStart = newStart;
          reportedNewEnd = newEnd;
        },
      );

      await tester.drag(find.text('Morning ritual (1h)'), const Offset(0, 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(reportedZoneId, zone.id);
      expect(reportedOriginalStart, zone.startMinutes);
      final delta = reportedNewStart! - zone.startMinutes;
      expect(delta, isNot(0));
      expect(reportedNewEnd! - zone.endMinutes, delta);
    },
  );

  testWidgets(
    'a resize/move released within the snap threshold (no real movement) '
    'reports nothing at all',
    (tester) async {
      var resizeCalled = false;
      var moveCalled = false;
      await pump(
        tester,
        editModeEnabled: true,
        onZoneResize: (_, _, _, _) => resizeCalled = true,
        onZoneMove: (_, _, _, _) => moveCalled = true,
      );

      final handles = find.byType(ResizeHandle);
      // 1px at 3px/min rounds to 0 real minutes after 5-minute snapping.
      await tester.drag(handles.last, const Offset(0, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(find.text('Morning ritual (1h)'), const Offset(0, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(resizeCalled, isFalse);
      expect(moveCalled, isFalse);
    },
  );
}
