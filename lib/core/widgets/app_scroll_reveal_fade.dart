import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_top_scroll_fade.dart';

/// An [AppTopScrollFade] that appears only as content scrolls under the
/// fixed header above it — fully shown once scrolled by its own height.
/// For a sheet whose first field sits right under its header: a permanent
/// fade there would wash that field out at rest. Requested directly: "in
/// the top part we should have that fade gradient as we have on bottom."
class AppScrollRevealFade extends StatelessWidget {
  const AppScrollRevealFade({
    super.key,
    required this.controller,
    required this.color,
  });

  final ScrollController controller;

  /// The surface the fade starts from — see [AppTopScrollFade.color].
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final height = theme.spacingXl;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        return Opacity(
          opacity: (offset / height).clamp(0.0, 1.0),
          child: child,
        );
      },
      child: AppTopScrollFade(color: color, height: height),
    );
  }
}
