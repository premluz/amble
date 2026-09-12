import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_icon_button.dart';

/// The "+" create button, floating independently above the bottom nav
/// pill — not sharing a pane with it. Replaces the old `AppBottomExtensionBar`
/// (2026-09-12, requested directly from a reference screenshot: "nav is
/// just 5 items + its outside"), which welded the "+" into its own bar
/// stacked directly on the nav. Positioned via a `Stack` at the bottom of
/// each screen's own body, same bottom-right spot on every tab that uses
/// it (Task view/Timeline, Manage, Tracked).
class AppFloatingCreateButton extends StatelessWidget {
  const AppFloatingCreateButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Positioned(
      right: theme.spacingMd,
      bottom: theme.spacingMd,
      child: SafeArea(
        top: false,
        child: AppIconButton(icon: Icons.add_rounded, onPressed: onPressed),
      ),
    );
  }
}
