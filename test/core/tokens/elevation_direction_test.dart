import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// "Fix elevation direction in dark mode: base background is darkest; each
/// layer above it (cards → nested rows → floating nav/modals) must get
/// progressively lighter, never darker — a floating nav bar should be the
/// lightest surface on screen."
///
/// The bug this pins: the nav bar painted `colorSurfacePrimary`, which in
/// dark mode resolves to `ink900` — the same value as the page background
/// — so the topmost floating element was also the darkest thing on screen.
void main() {
  group('dark mode elevation', () {
    final dark = AmbleTheme.dark;

    test('the floating overlay is strictly lighter than the page base', () {
      expect(
        _relativeLuminance(dark.colorSurfaceOverlay),
        greaterThan(_relativeLuminance(dark.colorSurfaceBase)),
      );
    });

    test('the overlay is the lightest surface in the stack', () {
      final overlay = _relativeLuminance(dark.colorSurfaceOverlay);
      for (final surface in {
        'base': dark.colorSurfaceBase,
        'primary': dark.colorSurfacePrimary,
        'timeline': dark.colorSurfaceTimeline,
      }.entries) {
        expect(
          overlay,
          greaterThan(_relativeLuminance(surface.value)),
          reason: 'overlay must sit above ${surface.key}',
        );
      }
    });

    test('the overlay is no longer the same value as the page background', () {
      // The literal defect: `colorSurfacePrimary` (what the nav used to
      // paint) IS `ink900` in dark mode, identical to the background.
      expect(dark.colorSurfaceOverlay, isNot(equals(dark.colorSurfacePrimary)));
    });
  });

  group('light mode elevation', () {
    final light = AmbleTheme.light;

    test('the overlay separates by shadow, not by getting lighter', () {
      // Light mode's base is already near-white, so "lighter" isn't
      // available as a depth cue — the overlay is allowed to match the
      // pane surface and rely on shadowPane instead.
      expect(
        _relativeLuminance(light.colorSurfaceOverlay),
        greaterThanOrEqualTo(_relativeLuminance(light.colorSurfaceBase)),
      );
      expect(light.shadowPane, isNotEmpty);
    });
  });

  test('the two themes resolve the overlay to different values', () {
    expect(
      AmbleTheme.dark.colorSurfaceOverlay,
      isNot(equals(AmbleTheme.light.colorSurfaceOverlay)),
    );
  });

  /// Reported directly: "on light mode we need to adjust bg and surfaces
  /// at the moment color same for bg and menu."
  ///
  /// A first pass put the light base one step off pure white (L=0.974),
  /// which measured 1.078:1 against the white nav overlay — no visible
  /// separation at all. The base was deepened so the surfaces above it
  /// have somewhere to go.
  group('light mode surface separation', () {
    final light = AmbleTheme.light;

    test('the overlay is visibly lighter than the base, not merely equal', () {
      final ratio = contrastRatio(
        light.colorSurfaceOverlay,
        light.colorSurfaceBase,
      );
      expect(
        ratio,
        greaterThan(1.15),
        reason:
            'overlay vs base is ${ratio.toStringAsFixed(3)}:1 — too close '
            'to read as a separate surface',
      );
    });

    test('the base is not effectively white', () {
      // The failure mode in one assertion: a near-white base leaves every
      // lighter surface nowhere to go.
      expect(
        _relativeLuminance(light.colorSurfaceBase),
        lessThan(0.90),
        reason: 'base is too close to white for surfaces to sit above it',
      );
    });
  });

  /// The bug that made every earlier token fix invisible: the tokens were
  /// right, but the app painted the wrong one. `scaffoldBackgroundColor`
  /// was wired to `colorSurfacePrimary` (a raised PANE — pure white in
  /// light mode) instead of `colorSurfaceBase` (the ground). In light mode
  /// that made the page and the white floating nav byte-identical, and it
  /// meant deepening the base token changed nothing on screen.
  ///
  /// **2026-09-12 — re-wired again, to `colorSurfaceTimeline`.** Once the
  /// bottom nav became a floating pill with margin on every side (rather
  /// than flush to the screen edge), that margin gap exposes
  /// `scaffoldBackgroundColor` directly — and every real screen already
  /// paints its own full-bleed `colorSurfaceTimeline`, not
  /// `colorSurfaceBase`. Reported directly: an unwanted extra patch of
  /// background color in that gap, in dark mode `colorSurfaceBase`
  /// (`ink900`, #121110) visibly darker than the `colorSurfaceTimeline`
  /// (`ink800`) surrounding it on every real screen. The ORIGINAL bug this
  /// group guards against (scaffold and pane byte-identical) is still
  /// avoided: `colorSurfaceTimeline` isn't `colorSurfaceOverlay` in either
  /// theme either — only the specific non-overlay token changed.
  group('the app paints its own screen background, not a mismatched base', () {
    test('main.dart wires scaffoldBackgroundColor to colorSurfaceTimeline', () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(
        source.contains(
          'scaffoldBackgroundColor: palette.colorSurfaceTimeline',
        ),
        isTrue,
        reason:
            'every real screen already paints colorSurfaceTimeline '
            'full-bleed — the scaffold color is only visible in the '
            'floating nav pill\'s own margin gap now, and must match '
            'what surrounds it there',
      );
    });

    test('colorSurfaceTimeline is never the same as colorSurfaceOverlay — '
        'the original scaffold-vs-pane collision this re-wiring must not '
        'reintroduce', () {
      for (final entry in {
        'light': AmbleTheme.light,
        'dark': AmbleTheme.dark,
      }.entries) {
        expect(
          entry.value.colorSurfaceTimeline,
          isNot(equals(entry.value.colorSurfaceOverlay)),
          reason:
              '${entry.key}: screen background and floating nav pill '
              'would be byte-identical',
        );
      }
    });

    test('base and overlay are never the same color in either theme', () {
      for (final entry in {
        'light': AmbleTheme.light,
        'dark': AmbleTheme.dark,
      }.entries) {
        expect(
          entry.value.colorSurfaceBase,
          isNot(equals(entry.value.colorSurfaceOverlay)),
          reason: '${entry.key}: page and floating nav share one color',
        );
      }
    });

    test('each theme steps base -> pane -> overlay in one direction', () {
      // Light elevates toward white, dark away from black. Either way the
      // three must be strictly ordered, never flat or reversed.
      final light = AmbleTheme.light;
      expect(
        _relativeLuminance(light.colorSurfacePrimary),
        greaterThan(_relativeLuminance(light.colorSurfaceBase)),
      );
      expect(
        _relativeLuminance(light.colorSurfaceOverlay),
        greaterThan(_relativeLuminance(light.colorSurfacePrimary)),
      );

      final dark = AmbleTheme.dark;
      expect(
        _relativeLuminance(dark.colorSurfacePrimary),
        greaterThan(_relativeLuminance(dark.colorSurfaceBase)),
      );
      expect(
        _relativeLuminance(dark.colorSurfaceOverlay),
        greaterThan(_relativeLuminance(dark.colorSurfacePrimary)),
      );
    });
  });
}
