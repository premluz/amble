import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/glass_pill_surface.dart';

/// The shared non-task pill surface, in two materials — requested
/// directly: "this ghost phantom state should have fill gray
/// semitransparent with bg blur glassy thing / make this style reusable
/// token / the imported should have fill also but just gray not the same
/// glassy / and no dotted line, no line at all", then refined: "this glass
/// phantom should be lighter on dark mode and darker on light mode."
void main() {
  double _luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

  group('glass material', () {
    // The whole point of the refinement. An earlier version painted
    // `colorSurfaceBlurOverlay`, which is `surface1`-derived and measured
    // WHITE-ish in light mode (luminance 1.000) and near-black in dark
    // (0.067) — i.e. exactly backwards for a tint meant to contrast with
    // its own background.
    test('the tint is DARKER in light mode and LIGHTER in dark mode', () {
      final light = GlassPillSurface.glassTint(AmbleTheme.light);
      final dark = GlassPillSurface.glassTint(AmbleTheme.dark);

      expect(
        _luminance(dark),
        greaterThan(_luminance(light)),
        reason: 'dark mode gets the lighter tint, light mode the darker — '
            'light=${_luminance(light)}, dark=${_luminance(dark)}',
      );
    });

    test('the tint is translucent — it is glass, not a solid fill', () {
      expect(GlassPillSurface.glassTint(AmbleTheme.light).a, lessThan(1.0));
      expect(GlassPillSurface.glassTint(AmbleTheme.dark).a, lessThan(1.0));
    });

    testWidgets('renders a real BackdropFilter — the fill alone would read '
        'as a dim rather than glass', (tester) async {
      final theme = AmbleTheme.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Center(
              child: GlassPillSurface(theme: theme, width: 24, height: 80),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('flat material', () {
    testWidgets('has NO blur — an imported event is a real calendar thing, '
        'not something airborne', (tester) async {
      final theme = AmbleTheme.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Center(
              child: GlassPillSurface(
                theme: theme,
                width: 24,
                height: 80,
                material: GlassPillMaterial.flat,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    // "no dotted line, no line at all" — the rail this replaced carried a
    // dashed outline painted by a hand-rolled CustomPainter.
    testWidgets('draws no border of any kind', (tester) async {
      final theme = AmbleTheme.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Center(
              child: GlassPillSurface(
                theme: theme,
                width: 24,
                height: 80,
                material: GlassPillMaterial.flat,
              ),
            ),
          ),
        ),
      );

      final borders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          .toList();
      expect(borders, isEmpty);
    });
  });

  // Both materials must track the "Pill shape" setting like every other
  // card — the phantom's old hardcoded `radiusSm` is exactly what didn't.
  testWidgets('both materials corner at theme.radiusPill, not a fixed value',
      (tester) async {
    for (final radius in <double>[4, 8, 999]) {
      for (final material in GlassPillMaterial.values) {
        final theme = AmbleTheme.light.copyWith(radiusPill: radius);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [theme]),
            home: Scaffold(
              body: Center(
                child: GlassPillSurface(
                  theme: theme,
                  width: 24,
                  height: 80,
                  material: material,
                ),
              ),
            ),
          ),
        );

        final found = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.borderRadius)
            .whereType<BorderRadius>()
            .map((r) => r.topLeft.x)
            .toList();

        expect(
          found,
          contains(radius),
          reason: '$material must corner at radiusPill=$radius',
        );
        // And the box still sizes correctly at every rung.
        final rect = tester.getRect(find.byType(GlassPillSurface));
        expect(rect.width, 24);
        expect(rect.height, 80);
      }
    }
  });
}
