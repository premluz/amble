import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/features/timeline/zone_day_timeline.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Confirms a zone container in the Spatial ZONE view renders at the exact
/// same top/left pixel as [ZoneBackgroundBlock] renders that SAME zone in
/// the Spatial TASK view — reported directly as a visible jump switching
/// between the two, since [ZoneDayTimeline]'s own container previously
/// used the zone's STRICT time/column position with no inset at all, while
/// [ZoneBackgroundBlock] insets horizontally by `-zoneBackgroundOffset`.
/// Both now apply the identical geometry — horizontal inset, and a top
/// edge landing exactly on the zone's own start time — so a zone doesn't
/// visibly move when the view switches.
void main() {
  const pixelsPerMinute = 3.0;
  final day = DateTime(2026, 9, 2);
  final zone = Zone(
    id: 'z1',
    title: 'Morning ritual',
    startMinutes: 7 * 60, // 07:00
    endMinutes: 8 * 60, // 08:00
  );

  testWidgets(
    'a zone container\'s top/left match ZoneBackgroundBlock\'s own formula '
    'for the same zone, day, and pixelsPerMinute',
    (tester) async {
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rangeStart = DateTime(day.year, day.month, day.day);
      final strictTop =
          DateTime(day.year, day.month, day.day)
              .add(Duration(minutes: zone.startMinutes))
              .difference(rangeStart)
              .inMinutes *
          pixelsPerMinute;

      // Located by the container widget itself, not by matching a
      // distinctive `top` value: TaskBoundaryMarkers renders its own
      // Positioneds for every hour tick, and now that a zone's top is its
      // plain strict time (no offset), that value is no longer unique in
      // the tree — a top-matching finder silently picked up an unrelated
      // Positioned instead.
      final zoneContainerPositioned = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byType(ZoneContainerBlock),
              matching: find.byType(Positioned),
            )
            .first,
      );

      // Unadjusted: a zone container's top edge lands exactly on its own
      // start time in BOTH views — the whole inter-zone gap comes off the
      // bottom instead. See ZoneBackgroundBlock's own geometry comment.
      expect(zoneContainerPositioned.top, strictTop);

      // left = hourGutterWidth (56.0, this file's own private constant,
      // matched here since it isn't exported) - zoneBackgroundOffset.
      expect(zoneContainerPositioned.left, 56.0 - zoneBackgroundOffset);
    },
  );
}
