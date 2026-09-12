import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics.dart';
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
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.haptics = const PlatformHaptics(),
  });

  final bool value;

  /// Injected rather than read from a provider, matching
  /// [AppPressFeedback]: this is a leaf presentational widget that several
  /// tests pump with no `ProviderScope`, and a `ref.watch` would turn a
  /// missing scope into a crash for every one of them.
  final Haptics haptics;

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
      // No haptic added here on purpose: CupertinoSwitch already plays its
      // own native one on toggle, so wrapping onChanged would fire two
      // buzzes for a single flip. The Material branch below has no such
      // built-in, which is exactly the kind of cross-platform gap the
      // adaptive layer exists to absorb.
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: theme.colorAccent,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (next) {
              haptics.play(AmbleHaptic.selection);
              onChanged!(next);
            },
      activeThumbColor: theme.colorSurfacePrimary,
      activeTrackColor: theme.colorAccent,
    );
  }
}
