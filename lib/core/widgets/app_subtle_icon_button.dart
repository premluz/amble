import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A "very subtle outline" circular icon button — a hairline border, no
/// fill — matching the Linear-style reference used for the shared
/// [AppCalendarHeader]'s utility row (sync/today/Edit Mode). Promoted out
/// of that widget 2026-09-12 so the Tracked tab's own view-cycle switcher
/// (moved here from the old bottom extension bar) uses the identical
/// style rather than a second, slightly different one.
///
/// Deliberately distinct from [AppIconButton] (filled accent circle,
/// reserved for primary actions like "+") — these are secondary utility
/// controls, so a filled accent circle would read as more important than
/// they are.
class AppSubtleIconButton extends StatelessWidget {
  const AppSubtleIconButton({
    super.key,
    this.icon,
    this.child,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
    this.borderColor,
  }) : assert(
         icon != null || child != null,
         'must provide either an icon or a custom child',
       );

  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final size = theme.spacingXl;
    return Tooltip(
      message: tooltip,
      child: AppPressFeedback(
        onTap: onTap,
        shape: BoxShape.circle,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? theme.colorBorder,
              width: theme.borderWidthHairline,
            ),
          ),
          child:
              child ??
              Icon(
                icon,
                size: theme.spacingLg,
                color: iconColor ?? theme.colorTextPrimary,
              ),
        ),
      ),
    );
  }
}
