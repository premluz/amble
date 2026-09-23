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

  test('every horizontal gap equals spacingTimelineGutter, at any width', () {
    for (final width in widths) {
      final gutter = theme.spacingTimelineGutter;

      final timeLeft = theme.timelineTimeLeft;
      final timeRight = timeLeft + theme.spacingTimeColumnWidth;
      final zoneLeft = theme.timelineZoneLeft;
      final zoneRight = zoneLeft + theme.timelineZoneWidth(width);
      final contentLeft = theme.timelineContentLeft(width);
      final contentRight = contentLeft + theme.timelineContentWidth(width);

      expect(
        timeLeft,
        moreOrLessEquals(gutter, epsilon: 0.01),
        reason: 'edge->time gap at width $width',
      );
      expect(
        zoneLeft - timeRight,
        moreOrLessEquals(gutter, epsilon: 0.01),
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
    Future<
      ({double timeColumnWidth, double zoneLeft})
    > measure(WidgetTester tester, {required bool use24Hour}) async {
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

    testWidgets('a 12-hour locale keeps the full width, so nothing clips', (
      tester,
    ) async {
      final result = await measure(tester, use24Hour: false);

      expect(result.timeColumnWidth, theme.spacingTimeColumnWidth);
      expect(result.zoneLeft, theme.timelineZoneLeft);
    });

    testWidgets('a 24-hour locale reclaims the slack its labels never use', (
      tester,
    ) async {
      final result = await measure(tester, use24Hour: true);

      expect(result.timeColumnWidth, lessThan(theme.spacingTimeColumnWidth));
      expect(
        result.zoneLeft,
        lessThan(theme.timelineZoneLeft),
        reason: 'zones must start earlier once the dead stripe is gone',
      );

      // Still wide enough for the label it has to render — the whole
      // point is to reclaim slack, never to clip.
      final painter = TextPainter(
        text: TextSpan(text: '13:41', style: theme.textCaptionMono),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        result.timeColumnWidth,
        greaterThanOrEqualTo(painter.width),
        reason: 'a 24-hour label must still fit its own column',
      );

      // The gap after the time text stays on the shared rhythm.
      expect(
        result.zoneLeft - (theme.timelineTimeLeft + result.timeColumnWidth),
        moreOrLessEquals(theme.spacingTimelineGutter, epsilon: 0.01),
      );
    });
  });
}
