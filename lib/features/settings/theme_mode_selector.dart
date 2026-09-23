import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/models/app_theme_mode.dart';
import '../../shared/providers/preferences_providers.dart';

/// Three-way Light/Dark/System control for the Settings screen.
///
/// A segmented chip row rather than a dropdown or a switch: three mutually
/// exclusive options where all three are worth seeing at once, and "System"
/// isn't expressible as an on/off toggle.
///
/// **2026-09-23 — uses the shared [AppSelectableChip], not its own private
/// `_ModeChip`.** Reported directly: this row rendered fully round while
/// the Appearance screen's Pill size/Text size chips looked square, even
/// though both were meant to be the same kind of control — two
/// independently hand-built chip widgets, neither actually tracking the
/// live "Pill shape" setting. See [AppSelectableChip]'s own doc comment
/// for the fix; this file now just consumes that shared widget instead of
/// keeping its own copy.
///
/// Writes go through `themeModeSettingProvider`, which persists via
/// [PreferencesRepository] — this widget never touches storage directly.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final current = ref.watch(themeModeSettingProvider);

    return Row(
      children: [
        for (final mode in AppThemeMode.values) ...[
          AppSelectableChip(
            label: _labelFor(mode),
            selected: mode == current,
            onTap: () => ref.read(themeModeSettingProvider.notifier).set(mode),
          ),
          if (mode != AppThemeMode.values.last)
            SizedBox(width: theme.spacingSm),
        ],
      ],
    );
  }

  String _labelFor(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };
}
