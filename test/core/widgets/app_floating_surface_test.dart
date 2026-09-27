import 'package:amble/core/tokens/floating_surface_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    test(
      'menu and drag share geometry across themes ${theme.colorSurfaceOverlay}',
      () {
        final menu = FloatingSurfaceTokens.shadow(
          theme,
          FloatingElevation.menu,
        );
        final drag = FloatingSurfaceTokens.shadow(
          theme,
          FloatingElevation.drag,
        );
        expect(menu.offset, const Offset(0, 6));
        expect(menu.blurRadius, 20);
        expect(menu.spreadRadius, -4);
        expect(drag.offset, const Offset(0, 12));
        expect(drag.blurRadius, 32);
        expect(drag.spreadRadius, -6);
        expect(drag.color.a, greaterThan(menu.color.a));
      },
    );

    testWidgets(
      'lift preserves child identity and restores unclipped handles ${theme.colorSurfaceOverlay}',
      (tester) async {
        final strength = ValueNotifier(0.0);
        addTearDown(strength.dispose);
        const marker = ValueKey('content');
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<double>(
              valueListenable: strength,
              builder: (_, value, child) => Center(
                child: AppFloatingSurface(
                  theme: theme,
                  strength: value,
                  borderRadius: BorderRadius.circular(theme.radiusXl),
                  elevation: FloatingElevation.drag,
                  child: child!,
                ),
              ),
              child: const SizedBox(key: marker, width: 160, height: 60),
            ),
          ),
        );
        final element = tester.element(find.byKey(marker));
        for (final value in [1.0, .5, 0.0]) {
          strength.value = value;
          await tester.pump();
          expect(tester.element(find.byKey(marker)), same(element));
          expect(
            tester.widget<ClipRRect>(find.byType(ClipRRect)).clipBehavior,
            value == 0 ? Clip.none : Clip.antiAlias,
          );
          expect(
            tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
            isTrue,
          );
        }
      },
    );

    testWidgets(
      'grouped dock uses glass; separate button uses solid ${theme.colorSurfaceOverlay}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                AppDockPane(
                  theme: theme,
                  children: const [Icon(Icons.edit), Icon(Icons.delete)],
                ),
                AppDockPane(
                  theme: theme,
                  children: const [Icon(Icons.arrow_back)],
                ),
              ],
            ),
          ),
        );
        final surfaces = tester
            .widgetList<AppFloatingSurface>(find.byType(AppFloatingSurface))
            .toList();
        expect(surfaces.map((s) => s.material), [
          FloatingMaterial.glass,
          FloatingMaterial.solid,
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
