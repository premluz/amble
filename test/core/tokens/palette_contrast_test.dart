import 'dart:math' as math;
import 'dart:ui';

import 'package:amble/core/tokens/color_primitives.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance, per the spec's own formula.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between two opaque colors, 1:1 to 21:1.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The rule this file enforces, stated directly in the design brief:
/// "every tag/accent color needs a light-mode variant and a dark-mode
/// variant checked independently for contrast against their respective
/// bg.base — never assume one hex works everywhere."
///
/// This is the brief's own suggested "run every tag color through a
/// contrast checker against both bg.base values" made automatic, so a
/// future palette edit cannot quietly drop a swatch below AA the way the
/// original shared ramp did.
void main() {
  /// Each theme's `bg.base` — the background a swatch on that theme is
  /// actually drawn against. Read from the THEME, not from a primitive
  /// picked by hand: an earlier version of this file asserted against
  /// `surface0` while the light theme's real base had moved to `cream0`,
  /// which is precisely the "measured against the wrong background" error
  /// these tests exist to catch.
  final lightBase = AmbleTheme.light.colorSurfaceBase;
  final darkBase = AmbleTheme.dark.colorSurfaceBase;

  const aa = 4.5;

  const hueNames = [
    'red',
    'orange',
    'amber',
    'yellow-green',
    'green',
    'teal',
    'cyan',
    'sky blue',
    'blue',
    'violet',
    'magenta',
    'pink/rose',
  ];

  group('category palette', () {
    test('the light ramp clears AA against the LIGHT base', () {
      final failures = <String>[];
      for (var i = 0; i < ColorPrimitives.categoryPalette12Light.length; i++) {
        final ratio = contrastRatio(
          ColorPrimitives.categoryPalette12Light[i],
          lightBase,
        );
        if (ratio < aa) {
          failures.add('${hueNames[i]} ${ratio.toStringAsFixed(2)}:1');
        }
      }
      expect(failures, isEmpty, reason: 'below $aa:1 on light: $failures');
    });

    test('the dark ramp clears AA against the DARK base', () {
      final failures = <String>[];
      for (var i = 0; i < ColorPrimitives.categoryPalette12.length; i++) {
        final ratio = contrastRatio(
          ColorPrimitives.categoryPalette12[i],
          darkBase,
        );
        if (ratio < aa) {
          failures.add('${hueNames[i]} ${ratio.toStringAsFixed(2)}:1');
        }
      }
      expect(failures, isEmpty, reason: 'below $aa:1 on dark: $failures');
    });

    test(
      'the two ramps are genuinely different values, not one shared set',
      () {
        // The actual defect being guarded against: pointing both themes at
        // one ramp passes every per-theme check above only by coincidence of
        // which background you test it on.
        expect(
          ColorPrimitives.categoryPalette12Light,
          isNot(equals(ColorPrimitives.categoryPalette12)),
        );
        for (var i = 0; i < hueNames.length; i++) {
          expect(
            ColorPrimitives.categoryPalette12Light[i],
            isNot(equals(ColorPrimitives.categoryPalette12[i])),
            reason: '${hueNames[i]} is the same in both themes',
          );
        }
      },
    );

    test('both ramps carry all 12 hues, so a stored colorToken still maps', () {
      expect(ColorPrimitives.categoryPalette12, hasLength(12));
      expect(ColorPrimitives.categoryPalette12Light, hasLength(12));
    });

    /// Pins the specific case reported as illegible, so it cannot regress
    /// back to a value that merely looks fine on a dark screenshot.
    test('teal — the reported failure — now clears AA on light', () {
      const tealIndex = 5;
      final before = contrastRatio(
        ColorPrimitives.categoryPalette12[tealIndex],
        lightBase,
      );
      final after = contrastRatio(
        ColorPrimitives.categoryPalette12Light[tealIndex],
        lightBase,
      );

      expect(before, lessThan(aa), reason: 'the old shared teal should fail');
      expect(after, greaterThanOrEqualTo(aa));
    });
  });

  // The old "built-in category icon colors" and "category badge tint
  // strength" groups that used to live here tested `categoryColors`/
  // `categoryIconColors`'s own hand-tuned `*Tint`/`*500`/`*500Dark`
  // primitives — removed along with those primitives themselves when
  // built-in categories were unified onto `categorySwatches` (the same
  // 12-swatch palette this file's own `category palette` group above
  // already covers), requested directly against a screenshot showing a
  // built-in category's light-mode pill visibly not matching its own
  // swatch. See `category_visual.dart`'s `resolveCategoryVisual` and
  // `color_primitives.dart`'s own removal note.
}
