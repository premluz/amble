import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/semantic_theme.dart';
import 'app_badge.dart';
import 'app_button.dart';
import 'app_floating_surface.dart';
import '../tokens/floating_surface_tokens.dart';

/// One floating, fully-rounded pane shared by contextual docks.
class AppDockPane extends StatelessWidget {
  const AppDockPane({
    super.key,
    required this.theme,
    required this.children,
    this.backgroundColor,
  });

  final AmbleTheme theme;
  final List<Widget> children;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AppDockSurface(
      theme: theme,
      grouped: children.length > 1,
      backgroundColor: backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.spacingXs,
          children: children,
        ),
      ),
    );
  }
}

/// One icon button inside an [AppDockPane].
class AppDockIconButton extends StatelessWidget {
  const AppDockIconButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.isDestructive = false,
    this.haptic = AmbleHaptic.tap,
    this.badgeCount,
  });

  final AmbleTheme theme;
  final IconData icon;
  final AmbleHaptic haptic;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;
  final bool isDestructive;

  /// When set, an [AppBadge] overlays the icon's top-right corner —
  /// requested directly for the Zones edit dock's own deselect button
  /// ("small circular badge with number... top right corner of icon
  /// within the button"). Null renders the button exactly as before
  /// (no overlay, no `Stack` introduced) — every existing caller is
  /// unaffected.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = AppButton(
      haptic: haptic,
      icon: icon,
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.ghost,
      tooltip: tooltip,
      onPressed: onTap,
      // colorDestructive (a stronger, more saturated red), not
      // colorTaskAlert (a coral warning/attention color) — requested
      // directly: "delete needs stronger red." colorTaskAlert answers a
      // different question ("this task needs attention") and keeps its
      // own meaning everywhere else it's still used.
      iconColor: isDestructive
          ? theme.colorDestructive
          : (selected ? theme.colorAccent : theme.colorTextSecondary),
    );

    final badgeCount = this.badgeCount;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? FloatingSurfaceTokens.selected(theme) : null,
        shape: BoxShape.circle,
      ),
      child: badgeCount == null
          ? button
          : Stack(
              clipBehavior: Clip.none,
              children: [
                button,
                // Top-right corner of the icon within the button —
                // requested directly. Negative offsets deliberately let
                // the badge sit half-outside the button's own circle
                // (the conventional "notification badge" placement),
                // hence `clipBehavior: Clip.none` above.
                Positioned(
                  top: -2,
                  right: -2,
                  child: AppBadge(count: badgeCount, size: AppBadgeSize.xs),
                ),
              ],
            ),
    );
  }
}

/// Grouped controls share glass; standalone actions keep a solid raised fill.
class AppDockSurface extends StatelessWidget {
  const AppDockSurface({
    super.key,
    required this.theme,
    required this.grouped,
    required this.child,
    this.backgroundColor,
  });
  final AmbleTheme theme;
  final bool grouped;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => AppFloatingSurface(
    theme: theme,
    borderRadius: BorderRadius.circular(theme.radiusPillFull),
    surfaceColor: backgroundColor,
    material: grouped ? FloatingMaterial.glass : FloatingMaterial.solid,
    child: child,
  );
}
