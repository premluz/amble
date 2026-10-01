import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Timeline's three-column contract, pinned at several viewport
/// widths so it cannot regress on a device size nobody tested by hand.
///
/// Reported repeatedly against annotated screenshots marking unequal
/// gaps, and finally rebuilt on this contract rather than patched again:
/// "can we have literally three columns of the same size... we would have
/// the same gap between these columns," with the reason given as the old
/// structure meaning "future problems with some other devices and sizes."
void main() {
  final theme = AmbleTheme.light;

  // A deliberately wide spread: the narrowest phone this ships to, the
  // common 390/430 iPhone widths, and a tablet-ish width. The whole point
  // of the contract is that the gaps do NOT vary with viewport.
  const widths = [320.0, 360.0, 390.0, 400.0, 430.0, 600.0, 834.0];

  test('every horizontal gap equals spacingTimelineGutter, at any width — '
      'except time->zone, which lends the time column a little', () {
    for (final width in widths) {
      final gutter = theme.spacingTimelineGutter;

      final timeLeft = theme.timelineTimeLeft;
      final timeRight = timeLeft + theme.timelineTimeColumnFixedWidth;
      final zoneLeft = theme.timelineZoneLeft;
      final zoneRight = zoneLeft + theme.timelineZoneWidth(width);
      final contentLeft = theme.timelineContentLeft(width);
      final contentRight = contentLeft + theme.timelineContentWidth(width);

      expect(
        timeLeft,
        moreOrLessEquals(gutter, epsilon: 0.01),
        reason: 'edge->time gap at width $width',
      );
      // The one exception: the time column borrows a little of this gap
      // (TimeColumnTokens.borrowedFromZoneGap) for its labels.
      expect(
        zoneLeft - timeRight,
        moreOrLessEquals(
          gutter - TimeColumnTokens.borrowedFromZoneGap,
          epsilon: 0.01,
        ),
        reason: 'time->zone gap at width $width',
      );
      expect(
        contentLeft - zoneRight,
        moreOrLessEquals(gutter, epsilon: 0.01),
        reason: 'zone->content gap at width $width',
      );
      expect(
        width - contentRight,
        moreOrLessEquals(gutter, epsilon: 0.01),
        reason: 'content->edge gap at width $width',
      );
    }
  });

  test('the content column never moves with the day\'s own overlap depth', () {
    // The previous layout derived the content column's x from
    // `dayPillLanes(slots)`, so a day with deeper overlapping pills pushed
    // every task title further right than a shallow day's. The column is
    // now a pure function of the viewport, which is what this pins: there
    // is no slots/lane parameter it COULD vary with.
    for (final width in widths) {
      expect(
        theme.timelineContentLeft(width),
        theme.timelineContentLeft(width),
      );
    }
  });

  test('the time column fits the widest label it must render', () {
    // "12:00 PM" in textCaptionMono measures 96.0 — the old 90 gutter was
    // narrower than its own contents, which is how hour labels overran
    // into the column beside them.
    expect(theme.spacingTimeColumnWidth, greaterThanOrEqualTo(96.0));
  });

  // [spacingTimeColumnWidth] is sized for "12:00 PM" (exactly 96.0 in
  // textCaptionMono). A 24-hour locale never renders that label — its
  // widest is "13:41" at 60.0 — so the column left a dead 36px stripe
  // between the time text and where zones began. Reported directly
  // against annotated screenshots marking that gap in red across both
  // views. `timelineTimeColumnWidth` measures the format actually in use
  // so the slack is reclaimed on 24-hour devices without clipping
  // 12-hour ones.
  group('time column width follows the clock format actually in use', () {
    Future<({double timeColumnWidth, double zoneLeft})> measure(
      WidgetTester tester, {
      required bool use24Hour,
    }) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: use24Hour),
          child: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox();
            },
          ),
        ),
      );
      return (
        timeColumnWidth: theme.timelineTimeColumnWidth(context),
        zoneLeft: theme.timelineZoneLeftFor(context),
      );
    }

    testWidgets('12- and 24-hour get the SAME fixed width — switching format '
        'never pushes the timeline — and every compact label fits', (
      tester,
    ) async {
      final twelve = await measure(tester, use24Hour: false);
      final twentyFour = await measure(tester, use24Hour: true);

      expect(twelve.timeColumnWidth, twentyFour.timeColumnWidth);
      expect(twelve.zoneLeft, twentyFour.zoneLeft);
      for (final label in ['12:45p', '12 PM', '13:41']) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: theme.textCaptionMono),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(
          painter.width,
          lessThanOrEqualTo(twelve.timeColumnWidth),
          reason: '"$label" fits the column',
        );
        painter.dispose();
      }
    });

    // Superseded 2026-09-30: this used to assert a 24-hour column came in
    // narrower than the old fixed 96. Both formats now share one fixed
    // width, which must also hold a task's bold, padded edge-time pill (it
    // ran its "m" under the zones otherwise) — see time_column_fit_test,
    // which checks that against the real fonts.
    testWidgets('a 24-hour label fits its column, and zones start one gap '
        'after it', (tester) async {
      final result = await measure(tester, use24Hour: true);

      // Wide enough for the label it has to render.
      final painter = TextPainter(
        text: TextSpan(text: '13:41', style: theme.textCaptionMono),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        result.timeColumnWidth,
        greaterThanOrEqualTo(painter.width),
        reason: 'a 24-hour label must still fit its own column',
      );

      // The gap after the time column: the gutter, less what the column
      // borrowed for its labels.
      expect(
        result.zoneLeft - (theme.timelineTimeLeft + result.timeColumnWidth),
        moreOrLessEquals(theme.timelineTimeToZoneGap, epsilon: 0.01),
      );
    });
  });
}
