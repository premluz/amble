import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:flutter/material.dart';

Widget floatingSurfaceDemo(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return ColoredBox(
    color: theme.colorSurfaceTimeline,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.spacingXl,
          children: [
            _sample(theme, FloatingElevation.menu, 'Context menu'),
            _sample(theme, FloatingElevation.drag, 'Dragged task'),
            AppDockPane(
              theme: theme,
              children: [
                _button(theme, Icons.view_agenda_outlined, 'List', true),
                _button(theme, Icons.view_week_outlined, 'Spatial', false),
              ],
            ),
            AppDockPane(
              theme: theme,
              children: [_button(theme, Icons.edit_outlined, 'Edit', false)],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sample(AmbleTheme theme, FloatingElevation elevation, String label) =>
    AppFloatingSurface(
      theme: theme,
      elevation: elevation,
      borderRadius: BorderRadius.circular(theme.radiusModal),
      child: Padding(
        padding: EdgeInsets.all(theme.spacingLg),
        child: Text(
          label,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
        ),
      ),
    );

Widget _button(AmbleTheme theme, IconData icon, String label, bool selected) =>
    AppDockIconButton(
      theme: theme,
      icon: icon,
      tooltip: label,
      selected: selected,
      onTap: () {},
    );
