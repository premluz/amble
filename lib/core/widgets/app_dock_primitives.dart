import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorSurfaceOverlay,
        borderRadius: BorderRadius.circular(theme.radiusPillFull),
        boxShadow: isDark ? null : theme.shadowPane,
      ),
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
  });

  final AmbleTheme theme;
  final IconData icon;
  final AmbleHaptic haptic;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      haptic: haptic,
      icon: icon,
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.ghost,
      tooltip: tooltip,
      onPressed: onTap,
      iconColor: isDestructive
          ? theme.colorTaskAlert
          : (selected ? theme.colorAccent : theme.colorTextSecondary),
    );
  }
}
