import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    testWidgets('a sheet is the per-mode sheet surface on the toolbar\'s '
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
      final dark = theme == AmbleTheme.dark;
      // Light: the page; dark: one step up, where a shadow barely reads.
      expect(
        SheetTokens.surface(theme),
        dark ? theme.colorSurfaceSecondary : theme.colorSurfaceBase,
      );
      // Controls inside stay one step off the sheet in both modes.
      expect(
        SheetTokens.inset(theme),
        dark ? theme.colorSurfaceField : theme.colorSurfaceSecondary,
      );
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
