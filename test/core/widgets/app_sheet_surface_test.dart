import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    testWidgets('a sheet is the page background on the toolbar\'s '
        'floating material, open at the bottom ${theme.colorSurfaceOverlay}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppSheetSurface(theme: theme, child: const SizedBox.shrink()),
        ),
      );
      final surface = tester.widget<AppFloatingSurface>(
        find.byType(AppFloatingSurface),
      );
      // The page's own background; in dark mode lifted by a faint light
      // layer (Apple's elevated dark background), not a whole palette step.
      final dark = theme == AmbleTheme.dark;
      Color lifted(Color base) => dark
          ? Color.alphaBlend(
              theme.colorTextPrimary.withValues(alpha: SheetTokens.darkLift),
              base,
            )
          : base;
      expect(SheetTokens.surface(theme), lifted(theme.colorSurfaceTimeline));
      expect(SheetTokens.inset(theme), lifted(theme.colorSurfaceSecondary));
      if (dark) {
        expect(
          SheetTokens.surface(theme).computeLuminance(),
          greaterThan(theme.colorSurfaceTimeline.computeLuminance()),
        );
      }
      expect(SheetTokens.inset(theme), isNot(SheetTokens.surface(theme)));
      expect(surface.surfaceColor, SheetTokens.surface(theme));
      expect(surface.material, FloatingMaterial.solid);
      expect(surface.openBottom, isTrue);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(AppFloatingSurface),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, SheetTokens.surface(theme));
    });
  }
}
