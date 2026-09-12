import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// The rounded card background every Settings row/section sits inside —
/// shared across the top-level Settings screen and every pushed sub-page.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.theme, required this.child});

  final AmbleTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorSurfaceSecondary,
        borderRadius: BorderRadius.circular(theme.radiusXl),
      ),
      child: child,
    );
  }
}
