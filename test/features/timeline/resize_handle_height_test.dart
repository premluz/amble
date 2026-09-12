import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';

/// Covers the "a very short task is all handle and no move zone" edge,
/// flagged when the top-edge resize handle was added: at the 5-minute
/// duration floor a pill is `sizeTaskBadge` (24px) tall, while two
/// default `spacingMd` (16px) handles claim 32px between them — more than
/// the block itself — so there was no draggable middle at all.
void main() {
  final theme = AmbleTheme.light;

  test('a tall block keeps the full default handle height', () {
    expect(
      resizeHandleHeightFor(theme: theme, blockHeight: 200),
      theme.spacingMd,
    );
  });

  test('the default height survives right down to the point where it '
      'exactly still fits the move band', () {
    // Two full handles plus the 12px band.
    final exactly = theme.spacingMd * 2 + 12.0;
    expect(
      resizeHandleHeightFor(theme: theme, blockHeight: exactly),
      theme.spacingMd,
    );
  });

  test('a short block shrinks both handles rather than swallowing the '
      'whole block', () {
    // The real case: the badge-floored 5-minute pill.
    const badgeFloored = 24.0;
    final handle = resizeHandleHeightFor(
      theme: theme,
      blockHeight: badgeFloored,
    );

    expect(handle, lessThan(theme.spacingMd));
    // The whole point: a move-only band actually survives.
    expect(badgeFloored - handle * 2, greaterThan(0));
  });

  test('handles never shrink below the minimum hittable size, even on an '
      'absurdly short block', () {
    // Better a cramped move band than two handles too small to grab.
    expect(resizeHandleHeightFor(theme: theme, blockHeight: 4), 8.0);
    expect(resizeHandleHeightFor(theme: theme, blockHeight: 0), 8.0);
  });

  test('the move band grows monotonically with block height', () {
    var previousBand = double.negativeInfinity;
    for (var h = 24.0; h <= 80.0; h += 4) {
      final band = h - resizeHandleHeightFor(theme: theme, blockHeight: h) * 2;
      expect(
        band,
        greaterThanOrEqualTo(previousBand),
        reason: 'a taller block must never have a smaller move band',
      );
      previousBand = band;
    }
  });

  /// The TASK pill's own (larger) variant — 2026-09-12, reported directly:
  /// "handle hit/active area should be larger outward (but not inward,
  /// bear in mind smallest pill size has also drag as move the entire pill
  /// interaction so we need affordance for all resize and move 3 different
  /// interactive hotspots)."
  group('taskResizeHandleHeightFor', () {
    test('a tall pill gets a genuinely larger target than the old default', () {
      final handle = taskResizeHandleHeightFor(theme: theme, blockHeight: 200);
      expect(
        handle,
        greaterThan(theme.spacingMd),
        reason:
            'the whole point of the report — spacingMd was the cramped '
            'value being complained about',
      );
      expect(handle, theme.spacingLg);
    });

    test('all three hotspots survive on the shortest possible pill', () {
      // The badge-floored 5-minute pill, where the three interactions
      // compete hardest.
      const badgeFloored = 24.0;
      final handle = taskResizeHandleHeightFor(
        theme: theme,
        blockHeight: badgeFloored,
      );

      expect(handle, greaterThanOrEqualTo(8.0), reason: 'still grabbable');
      expect(
        badgeFloored - handle * 2,
        greaterThan(0),
        reason:
            'move must not be squeezed out of existence — it is the '
            'only one of the three with no alternative entry point',
      );
    });

    test('move is preferred over resize when the pill cannot fit both', () {
      // A pill too short for two generous handles must shrink the
      // HANDLES, never the move band below its floor.
      final handle = taskResizeHandleHeightFor(theme: theme, blockHeight: 40);
      expect(handle, lessThan(theme.spacingLg));
      expect(40.0 - handle * 2, greaterThanOrEqualTo(0));
    });

    test('the move band never shrinks as the pill grows', () {
      var previousBand = double.negativeInfinity;
      for (var h = 24.0; h <= 200.0; h += 4) {
        final band =
            h - taskResizeHandleHeightFor(theme: theme, blockHeight: h) * 2;
        expect(band, greaterThanOrEqualTo(previousBand));
        previousBand = band;
      }
    });
  });
}
