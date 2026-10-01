import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';

/// Applies Developer → "Accent strength" to the Patterns screen only —
/// requested directly: "it should be only for patterns, not global." The
/// accent is pulled toward the theme's base surface, keeping its hue.
/// Release builds, and full strength, leave the theme untouched.
class PatternAccentScope extends ConsumerWidget {
  const PatternAccentScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDevConfigAvailable) return child;
    final strength = ref.watch(devAccentStrengthProvider);
    if (strength == DevAccentStrength.defaultValue) return child;
    final base = Theme.of(context);
    final palette = base.extension<AmbleTheme>()!;
    final resolved = palette.copyWith(
      colorAccent: Color.lerp(
        palette.colorSurfaceBase,
        palette.colorAccent,
        strength,
      )!,
    );
    return Theme(
      data: base.copyWith(
        extensions: [
          for (final extension in base.extensions.values)
            if (extension is! AmbleTheme) extension,
          resolved,
        ],
      ),
      child: child,
    );
  }
}
