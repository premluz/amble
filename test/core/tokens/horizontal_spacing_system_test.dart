import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_boundary_markers.dart';
import 'package:amble/features/timeline/zone_container_block.dart';

/// **2026-09-23 — rewritten for the three-column contract.** The Timeline
/// used to be described by two independent measurements
/// (`spacingScreenPadding`, `spacingHourGutter`) that agreed only by
/// coincidence — see `TimelineColumns`' own doc comment in
/// `semantic_theme.dart` for the full history of how that drifted, and
/// `timeline_columns_test.dart` for the actual column-geometry contract
/// this rebuild introduced. This file now checks that the TWO Timeline
/// views (spatial task view, non-spatial zone view) both actually build
/// their real widgets from that one shared contract, rather than
/// re-deriving the same distances their own way.
void main() {
  final light = AmbleTheme.light;
  final dark = AmbleTheme.dark;

  test('both themes agree on every Timeline column token', () {
    // A per-theme side inset would mean the page's left edge MOVED when
    // the user switched theme, which is never intended.
    expect(light.spacingScreenPadding, dark.spacingScreenPadding);
    expect(light.spacingTimeColumnWidth, dark.spacingTimeColumnWidth);
    expect(light.spacingTimelineGutter, dark.spacingTimelineGutter);
  });

  test('the non-spatial hour label sits at spacingTimelineGutter, the same '
      'inset the spatial view gives its own hour labels', () {
    expect(
      zoneRowTimeLabelEdgeInset,
      light.spacingTimelineGutter,
      reason:
          'zoneRowTimeLabelEdgeInset ($zoneRowTimeLabelEdgeInset) is the '
          'non-spatial view\'s hour-label inset; the spatial view\'s own '
          'hour labels sit at the same spacingTimelineGutter '
          '(${light.spacingTimelineGutter}). They must match or the hour '
          'visibly jumps between the two views.',
    );
  });

  test('the non-spatial content inset equals timelineZoneLeft, the same x '
      'the spatial view\'s own zone band starts at', () {
    expect(
      zoneContentLeftInset(light),
      light.timelineZoneLeft,
      reason:
          'zoneContentLeftInset (${zoneContentLeftInset(light)}) is where '
          'a zone card starts; timelineZoneLeft (${light.timelineZoneLeft}) '
          'is where the spatial view\'s own zone band starts. They are the '
          'same measurement and must not drift.',
    );
  });

  test('the time column fits its own widest label with real clearance', () {
    // `timeline_columns_test.dart` already pins the raw text measurement
    // (96.0). This checks the column leaves the SAME clearance
    // `hour_gutter_overflow_test.dart` requires against the gutter that
    // follows it, so a label can never paint into column 2.
    expect(
      light.spacingTimeColumnWidth,
      greaterThanOrEqualTo(96.0),
      reason: 'the widest label ("12:00 PM" in textCaptionMono) must fit '
          'inside the time column',
    );
  });

  testWidgets('the hour label TEXT renders at spacingTimelineGutter in both '
      'views — the same painted x, not just the same box origin', (
    tester,
  ) async {
    // The check that was missing, and the reason an 8px gap survived
    // three rounds of inspection: every existing test compared the values
    // passed IN (`leftInset`, `zoneRowTimeLabelEdgeInset`) and those
    // already agreed. What differed was what each widget did with that box
    // afterwards. Measuring the painted `Text` is the only way to see that.
    Future<double> textLeftOf(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [light]),
          home: Scaffold(body: Stack(children: [child])),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(Text).first).left;
    }

    final spatialTextLeft = await textLeftOf(
      TaskBoundaryMarkers(
        rangeStart: DateTime(2026, 9, 21, 9),
        rangeEnd: DateTime(2026, 9, 21, 10),
        pixelsPerMinute: 1.5,
        leftInset: light.spacingTimelineGutter,
      ),
    );

    // `leftPaddingToEscape: 0` — this label reaches its own absolute x by
    // escaping backwards through however much padding it is nested in;
    // with none, it lands on `zoneRowTimeLabelEdgeInset` directly, which
    // is the position under test.
    final nonSpatialTextLeft = await textLeftOf(
      ZoneRowTimeLabel(
        theme: light,
        text: '9:00 AM',
        leftPaddingToEscape: 0,
        reservedWidth: zoneRowTimeLabelReservedWidth,
      ),
    );

    expect(
      spatialTextLeft,
      moreOrLessEquals(light.spacingTimelineGutter, epsilon: 0.5),
      reason:
          'the spatial view\'s hour text painted at ${spatialTextLeft}px, '
          'not the shared ${light.spacingTimelineGutter}px inset',
    );
    expect(
      nonSpatialTextLeft,
      moreOrLessEquals(spatialTextLeft, epsilon: 0.5),
      reason:
          'the non-spatial view\'s hour text painted at '
          '${nonSpatialTextLeft}px against the spatial view\'s '
          '${spatialTextLeft}px — the hour visibly jumps between views',
    );
  });
}
