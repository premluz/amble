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

  /// The gap that let the reported bug survive an earlier "all swatches
  /// pass" session: only the 12-swatch CUSTOM category palette was
  /// checked. The five BUILT-IN categories render through their own
  /// hand-tuned `*500` / `*500Dark` maps and bypass that ramp entirely, so
  /// three of them (ochre 4.27:1, periwinkle 4.11:1, neutral 4.50:1) sat
  /// at or under the floor on light while the suite stayed green.
  group('built-in category icon colors', () {
    final lightIcons = {
      'neutral': ColorPrimitives.neutral500,
      'clay': ColorPrimitives.clay500,
      'ochre': ColorPrimitives.ochre500,
      'periwinkle': ColorPrimitives.periwinkle500,
      'berry': ColorPrimitives.berry500,
    };
    final darkIcons = {
      'neutral': ColorPrimitives.neutral500Dark,
      'clay': ColorPrimitives.clay500Dark,
      'ochre': ColorPrimitives.ochre500Dark,
      'periwinkle': ColorPrimitives.periwinkle500Dark,
      'berry': ColorPrimitives.berry500Dark,
    };

    test('every light icon color clears AA on the light base', () {
      final failures = <String>[];
      lightIcons.forEach((name, color) {
        final ratio = contrastRatio(color, lightBase);
        if (ratio < aa) failures.add('$name ${ratio.toStringAsFixed(2)}:1');
      });
      expect(failures, isEmpty, reason: 'below $aa:1 on light: $failures');
    });

    test('every dark icon color clears AA on the dark base', () {
      final failures = <String>[];
      darkIcons.forEach((name, color) {
        final ratio = contrastRatio(color, darkBase);
        if (ratio < aa) failures.add('$name ${ratio.toStringAsFixed(2)}:1');
      });
      expect(failures, isEmpty, reason: 'below $aa:1 on dark: $failures');
    });

    test('the light and dark icon sets are genuinely different values', () {
      for (final name in lightIcons.keys) {
        expect(
          lightIcons[name],
          isNot(equals(darkIcons[name])),
          reason: '$name shares one value across both themes',
        );
      }
    });
  });

  /// Reported directly, after the tints already cleared contrast math:
  /// "color of container is pale on light mode[,] needs to be stronger" —
  /// specifically called out for the personal (blue) and work (teal)
  /// badges. The tints (`*Tint`, the badge FILL a category icon sits on)
  /// were near-white (L≈0.95-0.98) and read as washed-out even though
  /// icon-on-tint contrast passed AA. Deepened to L=0.90 with chroma
  /// raised, verified here on two axes: that they actually got stronger,
  /// and that the icon glyph sitting on them still clears a real
  /// contrast floor (3:1 — the WCAG floor for a decorative graphic/icon,
  /// not the 4.5:1 text floor, since deepening the badge necessarily
  /// narrows its gap to the icon).
  group('category badge tint strength', () {
    final tints = {
      'clay': ColorPrimitives.clayTint,
      'ochre': ColorPrimitives.ochreTint,
      'periwinkle': ColorPrimitives.periwinkleTint,
      'berry': ColorPrimitives.berryTint,
    };
    final icons = {
      'clay': ColorPrimitives.clay500,
      'ochre': ColorPrimitives.ochre500,
      'periwinkle': ColorPrimitives.periwinkle500,
      'berry': ColorPrimitives.berry500,
    };

    test('every tint sits at L=0.90, not near-white', () {
      // HSLuminance is a rough proxy; check via contrast against pure
      // white instead — a near-white tint (L>0.95) would measure very
      // close to 1:1 against white, a genuinely deepened one measurably
      // more.
      const white = Color(0xFFFFFFFF);
      for (final entry in tints.entries) {
        final ratio = contrastRatio(entry.value, white);
        expect(
          ratio,
          greaterThan(1.15),
          reason:
              '${entry.key} tint measures ${ratio.toStringAsFixed(3)}:1 '
              'against white — too close to white to read as "stronger"',
        );
      }
    });

    test('the icon glyph still clears the 3:1 icon floor on its own tint', () {
      final failures = <String>[];
      for (final name in tints.keys) {
        final ratio = contrastRatio(icons[name]!, tints[name]!);
        if (ratio < 3.0) failures.add('$name ${ratio.toStringAsFixed(2)}:1');
      }
      expect(failures, isEmpty, reason: 'below 3:1 icon floor: $failures');
    });
  });
}
