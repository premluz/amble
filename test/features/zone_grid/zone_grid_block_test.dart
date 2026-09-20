import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_edge_time_label.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/shared/models/zone.dart';

/// Covers the corrected gutter alignment for `ZoneGridBlock`'s own live
/// start/end time labels — reported directly: "zones also blue time from
/// to on the left." The label must sit on the grid's own hour-axis
/// column (the SAME x every "HH:00" tick uses), not merely at this day
/// column's own left edge.
void main() {
  final theme = AmbleTheme.light;
  final zone = Zone(
    id: 'z',
    title: 'Focus block',
    startMinutes: 9 * 60,
    endMinutes: 10 * 60,
  );

  Future<void> pump(WidgetTester tester, {required double dayColumnLeft}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: Stack(
              children: [
                Positioned(
                  left: dayColumnLeft,
                  width: 80,
                  top: 0,
                  bottom: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ZoneGridBlock(
                        theme: theme,
                        zone: zone,
                        top: 0,
                        height: 90,
                        isSelected: true,
                        dayColumnLeft: dayColumnLeft,
                        liveStartMinutes: 9 * 60,
                        liveEndMinutes: 10 * 60,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'the live start label sits at the SAME absolute x regardless of which '
    'day column the block is in — the shared gutter x, not the column\'s '
    'own left edge',
    (tester) async {
      await pump(tester, dayColumnLeft: 60);
      final day1X = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      await pump(tester, dayColumnLeft: 60 + 80 * 5);
      final day6X = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      expect(
        day1X,
        moreOrLessEquals(day6X, epsilon: 0.5),
        reason:
            'a zone in a LATER day column must show its live time label '
            'at the exact same x as one in an earlier column — both are '
            'the same hour-axis gutter, not the day column\'s own edge',
      );
    },
  );

  testWidgets(
    'the live label sits well LEFT of the day column\'s own left edge — '
    'inside the gutter, not hugging the column',
    (tester) async {
      const dayColumnLeft = 200.0;
      await pump(tester, dayColumnLeft: dayColumnLeft);

      final labelX = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      expect(labelX, lessThan(dayColumnLeft - 50));
    },
  );
}
