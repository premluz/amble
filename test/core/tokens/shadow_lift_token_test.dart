import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';

/// Covers the `shadowLift` Tier 2 token added for the drag lift state.
///
/// `AmbleTheme` is a [ThemeExtension], so a new field has to be threaded
/// through `copyWith` and `lerp` as well as the constructor — miss either
/// and the token silently reverts to the other palette's value during a
/// theme animation, which is exactly the kind of bug that only shows up
/// mid-transition and is painful to catch by eye.
void main() {
  test('both palettes define a lift shadow', () {
    expect(AmbleTheme.light.shadowLift, isNotEmpty);
    expect(AmbleTheme.dark.shadowLift, isNotEmpty);
  });

  test('the dark shadow is stronger than the light one', () {
    // Depth on a near-black surface has to come from a darker-than-
    // background shadow, so the dark variant is deliberately much more
    // opaque. If someone later "simplifies" the two palettes to share one
    // value, this fails rather than quietly making dark-mode drag flat.
    final lightAlpha = AmbleTheme.light.shadowLift.first.color.a;
    final darkAlpha = AmbleTheme.dark.shadowLift.first.color.a;

    expect(darkAlpha, greaterThan(lightAlpha));
  });

  test('the lift shadow is larger than the sheet button shadow it '
      'follows — a lifted element should read as clearly nearer', () {
    // The Continue button's shadow uses spacingMd blur / spacingXs offset.
    // The lift's *widest* layer must exceed both, or "lift" is
    // indistinguishable from the app's existing resting elevation.
    //
    // Checks the widest layer rather than `.first` because the lift is a
    // two-layer shadow: a tight contact layer plus a wide ambient one. An
    // earlier version asserted on `.first` and failed the moment the
    // contact layer was added — the assertion was about reach, not about
    // whichever layer happens to be declared first.
    final widest = AmbleTheme.light.shadowLift.reduce(
      (a, b) => a.blurRadius >= b.blurRadius ? a : b,
    );

    expect(widest.blurRadius, greaterThan(AmbleTheme.light.spacingMd));
    expect(widest.offset.dy, greaterThan(AmbleTheme.light.spacingXs));
  });

  test('both palettes layer a tight contact shadow under a wide ambient '
      'one — a single wide shadow washes out rather than reading as depth', () {
    for (final palette in [AmbleTheme.light, AmbleTheme.dark]) {
      expect(palette.shadowLift.length, greaterThanOrEqualTo(2));
      final blurs = palette.shadowLift.map((s) => s.blurRadius).toList();
      expect(blurs.reduce((a, b) => a < b ? a : b), lessThan(20));
      expect(blurs.reduce((a, b) => a > b ? a : b), greaterThan(20));
    }
  });

  test('copyWith preserves shadowLift when it is not overridden', () {
    final copy = AmbleTheme.light.copyWith(spacingMd: 99);

    expect(copy.shadowLift, AmbleTheme.light.shadowLift);
  });

  test('copyWith replaces shadowLift when it is overridden', () {
    const replacement = [BoxShadow(blurRadius: 1)];
    final copy = AmbleTheme.light.copyWith(shadowLift: replacement);

    expect(copy.shadowLift, replacement);
  });

  test('lerp interpolates shadowLift rather than dropping it', () {
    final midway = AmbleTheme.light.lerp(AmbleTheme.dark, 0.5);

    expect(midway.shadowLift, isNotEmpty);
    // At the midpoint the alpha should sit between the two endpoints —
    // proof it actually interpolated instead of snapping to one side.
    final lightAlpha = AmbleTheme.light.shadowLift.first.color.a;
    final darkAlpha = AmbleTheme.dark.shadowLift.first.color.a;
    final midAlpha = midway.shadowLift.first.color.a;

    expect(midAlpha, greaterThan(lightAlpha));
    expect(midAlpha, lessThan(darkAlpha));
  });

  test('lerp at the endpoints returns each palette\'s own shadow', () {
    final atStart = AmbleTheme.light.lerp(AmbleTheme.dark, 0.0);
    final atEnd = AmbleTheme.light.lerp(AmbleTheme.dark, 1.0);

    expect(
      atStart.shadowLift.first.color.a,
      closeTo(AmbleTheme.light.shadowLift.first.color.a, 0.001),
    );
    expect(
      atEnd.shadowLift.first.color.a,
      closeTo(AmbleTheme.dark.shadowLift.first.color.a, 0.001),
    );
  });
}
