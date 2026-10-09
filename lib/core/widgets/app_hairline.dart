import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';

/// The desktop shell's pane dividers and the calendar grid: 1 point wide
/// ([ShellLayoutTokens.lineWidth], as in Notion Calendar), where the app's
/// general [AmbleTheme.borderWidthHairline] is 2 points and reads heavy.
abstract final class AppHairline {
  static const double width = ShellLayoutTokens.lineWidth;

  /// [AmbleTheme.colorBorder] at [alpha], [width] wide.
  static BorderSide side(BuildContext context, double alpha) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return BorderSide(
      color: theme.colorBorder.withValues(alpha: alpha),
      width: width,
    );
  }
}
