import 'package:flutter/widgets.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_floating_surface.dart';

/// A bottom sheet's panel: the floating edge and shadow the toolbar panes
/// use ([AppFloatingSurface]), solid in [SheetTokens.surface], rounded on
/// top and open at the bottom where it meets the screen edge.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({super.key, required this.theme, required this.child});

  final AmbleTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppFloatingSurface(
    theme: theme,
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(theme.radiusModal),
    ),
    surfaceColor: SheetTokens.surface(theme),
    material: FloatingMaterial.solid,
    openBottom: true,
    child: child,
  );
}
