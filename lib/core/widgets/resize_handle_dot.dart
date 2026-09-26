import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Shared resize affordance, separated from selection rings by the surface.
class ResizeHandleDot extends StatelessWidget {
  const ResizeHandleDot({super.key, required this.theme});

  final AmbleTheme theme;

  static double edgeInset(AmbleTheme theme) => theme.borderWidthHairline / 2;

  @override
  Widget build(BuildContext context) => Container(
    width: theme.spacingSm,
    height: theme.spacingSm,
    decoration: BoxDecoration(
      color: theme.colorAccent,
      shape: BoxShape.circle,
      border: Border.all(
        color: theme.colorSurfacePrimary,
        width: theme.borderWidthHairline / 2,
      ),
    ),
  );
}
