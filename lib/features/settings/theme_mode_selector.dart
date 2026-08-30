import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/app_theme_mode.dart';
import '../../shared/providers/preferences_providers.dart';

/// Three-way Light/Dark/System control for the Settings screen.
///
/// A segmented chip row rather than a dropdown or a switch: three mutually
/// exclusive options where all three are worth seeing at once, and "System"
/// isn't expressible as an on/off toggle. Mirrors the chip styling already
/// used by the recurrence frequency and tracked-behavior pickers, so this
/// reads as the same kind of control rather than a new idiom.
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
          _ModeChip(
            theme: theme,
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorAccent : theme.colorSurfaceTimeline,
          borderRadius: BorderRadius.circular(theme.radiusTaskPill),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(
            color: selected
                ? theme.colorSurfacePrimary
                : theme.colorTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
