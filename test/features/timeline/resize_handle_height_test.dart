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
}
