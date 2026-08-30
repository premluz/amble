import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Adaptive on/off switch, branching Cupertino vs. Material the same way
/// [AppSheet]/[AppAlertDialog] do — screens never import `Switch` or
/// `CupertinoSwitch` directly, per docs/CONSTITUTION.md design principle 4.
///
/// Unlike [AppSlider] (custom-painted because the design needed a track
/// neither platform widget could produce), a switch has no such
/// requirement, so this wraps the real platform controls and keeps their
/// native feel — only the active color is themed, from Tier 2 tokens.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null disables the switch — matches the platform widgets' own
  /// disabled-control idiom (`onChanged: null`) rather than a separate
  /// `enabled` flag, so this stays a thin wrap of the real controls.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isCupertino =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (isCupertino) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: theme.colorAccent,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.colorSurfacePrimary,
      activeTrackColor: theme.colorAccent,
    );
  }
}
