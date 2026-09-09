import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A circular, icon-only adaptive button — the FAB-equivalent for this
/// design system. Cupertino on iOS, Material elsewhere, consuming only
/// Tier 2 tokens. Screens should never reach for `FloatingActionButton`/
/// `CupertinoButton` directly; this is the only entry point, per
/// docs/CONSTITUTION.md design principle 4.
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final size = theme.spacingXl * 1.5;

    // One interaction on both platforms, via AppPressFeedback, replacing
    // the previous CupertinoButton/InkWell platform split — see that
    // widget's own doc comment for why the adaptive branch was dropped
    // here rather than kept alongside it (Cupertino gave no positional
    // feedback at all, so the two platforms didn't actually match).
    return AppPressFeedback(
      onTap: onPressed,
      shape: BoxShape.circle,
      // The fill is the accent color, so the wash rides on the light
      // foreground the icon already uses — a dark wash would barely
      // register against it.
      rippleColor: theme.colorSurfacePrimary,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorAccent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorSurfacePrimary),
      ),
    );
  }
}
