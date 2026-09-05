import 'package:flutter_test/flutter_test.dart';

/// The scroll-position round trip shared by BOTH spatial views (Task and
/// Zone): each reports its centered time-of-day as it scrolls, and each
/// restores that same time on mount/day-change. The two directions must be
/// exact inverses, and — critically — must agree ACROSS the two views even
/// though they render at different scales (Task view 1.5 px/min, Zone view
/// 3.0 px/min by default, both user-adjustable in Dev settings).
///
/// Reported directly: "scroll level goes out of sync in spatial views."
///
/// Note on what these tests do and don't prove: the report/restore pair is
/// symmetric at ANY single scale, and — verified here — a Task->Zone->Task
/// round trip through the pure formulas returns the same minute even
/// WITHOUT the top-padding term, because the padding cancels itself out on
/// both sides. The padding term was still added to both directions (so the
/// reported minute matches the time actually centered on screen rather than
/// being 24px off), but it is NOT what caused the reported drift.
///
/// The asymmetry these tests do expose is the `.clamp(0, maxScrollExtent)`
/// in the real `jumpTo` call: the two views have different content heights
/// (24h * their own pixelsPerMinute), so a time that's reachable in one can
/// clamp in the other, and the position silently becomes the clamped one.
/// The last test pins that behavior down.
///
/// These are the two formulas as implemented in
/// `_DayTimelineState`/`_ZoneDayTimelineState` — kept here as a pure,
/// executable statement of the contract, since the real methods are private
/// to their States and need a live ScrollController to run.
int reportedMinutes({
  required double scrollOffset,
  required double viewportHeight,
  required double pixelsPerMinute,
  required double topPadding,
  required int rangeStartMinutes,
}) {
  final centerOffset = scrollOffset + (viewportHeight / 2) - topPadding;
  return rangeStartMinutes + (centerOffset / pixelsPerMinute).round();
}

double restoreOffset({
  required int targetMinutes,
  required double viewportHeight,
  required double pixelsPerMinute,
  required double topPadding,
  required int rangeStartMinutes,
}) {
  final minutesSinceStart = targetMinutes - rangeStartMinutes;
  return (minutesSinceStart * pixelsPerMinute) +
      topPadding -
      (viewportHeight / 2);
}

void main() {
  const topPadding = 24.0; // theme.spacingLg
  const viewportHeight = 800.0;
  const taskViewScale = 1.5;
  const zoneViewScale = 3.0;
  const rangeStartMinutes = 0; // full 24h day starts at midnight

  group('report/restore are exact inverses within one view', () {
    test('Task view scale', () {
      const offset = 1234.0;
      final minutes = reportedMinutes(
        scrollOffset: offset,
        viewportHeight: viewportHeight,
        pixelsPerMinute: taskViewScale,
        topPadding: topPadding,
        rangeStartMinutes: rangeStartMinutes,
      );
      final restored = restoreOffset(
        targetMinutes: minutes,
        viewportHeight: viewportHeight,
        pixelsPerMinute: taskViewScale,
        topPadding: topPadding,
        rangeStartMinutes: rangeStartMinutes,
      );
      // Within one pixelsPerMinute of the original — the only loss is the
      // deliberate rounding to whole minutes.
      expect((restored - offset).abs(), lessThanOrEqualTo(taskViewScale));
    });

    test('Zone view scale', () {
      const offset = 4321.0;
      final minutes = reportedMinutes(
        scrollOffset: offset,
        viewportHeight: viewportHeight,
        pixelsPerMinute: zoneViewScale,
        topPadding: topPadding,
        rangeStartMinutes: rangeStartMinutes,
      );
      final restored = restoreOffset(
        targetMinutes: minutes,
        viewportHeight: viewportHeight,
        pixelsPerMinute: zoneViewScale,
        topPadding: topPadding,
        rangeStartMinutes: rangeStartMinutes,
      );
      expect((restored - offset).abs(), lessThanOrEqualTo(zoneViewScale));
    });
  });

  test('a Task -> Zone -> Task round trip returns to the same MINUTE, despite '
      'the two views using different pixelsPerMinute', () {
    // Start centered on 09:30 in Task view.
    const startMinutes = 9 * 60 + 30;

    final taskOffset = restoreOffset(
      targetMinutes: startMinutes,
      viewportHeight: viewportHeight,
      pixelsPerMinute: taskViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );
    // Task view reports what it's centered on...
    final reportedFromTask = reportedMinutes(
      scrollOffset: taskOffset,
      viewportHeight: viewportHeight,
      pixelsPerMinute: taskViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );
    // ...Zone view restores to it, then reports its own centered time...
    final zoneOffset = restoreOffset(
      targetMinutes: reportedFromTask,
      viewportHeight: viewportHeight,
      pixelsPerMinute: zoneViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );
    final reportedFromZone = reportedMinutes(
      scrollOffset: zoneOffset,
      viewportHeight: viewportHeight,
      pixelsPerMinute: zoneViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );

    expect(reportedFromTask, startMinutes);
    expect(reportedFromZone, startMinutes);
  });

  test('the round trip survives clamping to the scroll extent only when the '
      'target is genuinely reachable — a target near midnight clamps to 0 and '
      'the reported minute then reflects the CLAMPED position, not the '
      'requested one', () {
    // This is the real asymmetry between the two views: they have
    // different content heights (24h * pixelsPerMinute), so the same
    // requested time can be reachable in one view and clamped in the
    // other. restoreOffset itself is scale-correct; jumpTo's clamp to
    // [0, maxScrollExtent] is what silently changes the position.
    const nearMidnight = 5; // 00:05
    final requested = restoreOffset(
      targetMinutes: nearMidnight,
      viewportHeight: viewportHeight,
      pixelsPerMinute: taskViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );
    expect(
      requested,
      lessThan(0),
      reason:
          'centering 00:05 needs to scroll above the top of the content, '
          'so the real jumpTo clamps it to 0',
    );

    final afterClamp = reportedMinutes(
      scrollOffset: 0,
      viewportHeight: viewportHeight,
      pixelsPerMinute: taskViewScale,
      topPadding: topPadding,
      rangeStartMinutes: rangeStartMinutes,
    );
    expect(afterClamp, isNot(nearMidnight));
  });
}
