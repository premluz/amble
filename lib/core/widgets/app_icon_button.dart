import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

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

    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorAccent,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: theme.colorSurfacePrimary),
    );

    if (isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: button,
      );
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: button,
      ),
    );
  }
}
