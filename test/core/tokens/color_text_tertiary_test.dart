import 'dart:math' as math;
import 'dart:ui';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Requested directly: "Make zone names even subtler color (add new
/// subtler semantic token)." `colorTextTertiary` is that new token —
/// deliberately lower-contrast than `colorTextSecondary` (which zone names
/// used before this) while staying past WCAG's 3:1 floor for
/// large/decorative text.
void main() {
  group('colorTextTertiary', () {
    test('exists as its own distinct value in both themes', () {
      expect(
        AmbleTheme.light.colorTextTertiary,
        isNot(equals(AmbleTheme.light.colorTextSecondary)),
      );
      expect(
        AmbleTheme.dark.colorTextTertiary,
        isNot(equals(AmbleTheme.dark.colorTextSecondary)),
      );
    });

    test(
      'is genuinely subtler (lower contrast) than secondary, both themes',
      () {
        final lightBase = AmbleTheme.light.colorSurfaceBase;
        final darkBase = AmbleTheme.dark.colorSurfaceBase;

        final lightTertiaryRatio = _contrastRatio(
          AmbleTheme.light.colorTextTertiary,
          lightBase,
        );
        final lightSecondaryRatio = _contrastRatio(
          AmbleTheme.light.colorTextSecondary,
          lightBase,
        );
        expect(
          lightTertiaryRatio,
          lessThan(lightSecondaryRatio),
          reason:
              'tertiary $lightTertiaryRatio:1 should read subtler than '
              'secondary $lightSecondaryRatio:1',
        );

        final darkTertiaryRatio = _contrastRatio(
          AmbleTheme.dark.colorTextTertiary,
          darkBase,
        );
        final darkSecondaryRatio = _contrastRatio(
          AmbleTheme.dark.colorTextSecondary,
          darkBase,
        );
        expect(darkTertiaryRatio, lessThan(darkSecondaryRatio));
      },
    );

    test('still clears the 3:1 floor for large/decorative text', () {
      final lightRatio = _contrastRatio(
        AmbleTheme.light.colorTextTertiary,
        AmbleTheme.light.colorSurfaceBase,
      );
      final darkRatio = _contrastRatio(
        AmbleTheme.dark.colorTextTertiary,
        AmbleTheme.dark.colorSurfaceBase,
      );
      expect(lightRatio, greaterThanOrEqualTo(3.0));
      expect(darkRatio, greaterThanOrEqualTo(3.0));
    });

    test('copyWith preserves colorTextTertiary when not overridden', () {
      final resolved = AmbleTheme.light.copyWith(colorTextPrimary: null);
      expect(resolved.colorTextTertiary, AmbleTheme.light.colorTextTertiary);
    });

    test('copyWith replaces colorTextTertiary when overridden', () {
      const override = Color(0xFF123456);
      final resolved = AmbleTheme.light.copyWith(colorTextTertiary: override);
      expect(resolved.colorTextTertiary, override);
    });

    test('lerp interpolates colorTextTertiary rather than dropping it', () {
      final midpoint = AmbleTheme.light.lerp(AmbleTheme.dark, 0.5);
      final expected = Color.lerp(
        AmbleTheme.light.colorTextTertiary,
        AmbleTheme.dark.colorTextTertiary,
        0.5,
      );
      expect(midpoint.colorTextTertiary, expected);
    });
  });
}
