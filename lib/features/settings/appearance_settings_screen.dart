import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/models/task_size.dart';
import '../../shared/providers/preferences_providers.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';
import 'theme_mode_selector.dart';

Future<void> showAppearanceSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const AppearanceSettingsScreen()),
  );
}

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SettingsDetailScaffold(
      title: 'Appearance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System follows your device\'s light/dark setting.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                SizedBox(height: theme.spacingMd),
                const ThemeModeSelector(),
              ],
            ),
          ),
          SizedBox(height: theme.spacingSm),
          // Split from "Task size" into two independent controls —
          // requested directly: "Settings in appearance separately font
          // size and separately pill size, let's split this, and should
          // affect all pills its text." An existing user's prior single
          // choice is migrated once into both new settings on first read
          // (see `TaskFontSizeSetting`'s own doc comment) — nothing
          // visibly changes for them until they touch one of these two
          // pickers independently.
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pill size',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  'The size of a task\'s badge/icon — applies everywhere: '
                  'Task view, List view, and Zone view.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                Row(
                  children: [
                    for (final size in TaskSize.values) ...[
                      if (size != TaskSize.values.first)
                        SizedBox(width: theme.spacingSm),
                      AppSelectableChip(
                        label: switch (size) {
                          TaskSize.sm => 'Small',
                          TaskSize.md => 'Medium',
                          TaskSize.lg => 'Large',
                        },
                        selected: ref.watch(taskSizeSettingProvider) == size,
                        onTap: () => ref
                            .read(taskSizeSettingProvider.notifier)
                            .set(size),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacingSm),
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Text size',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  'The size of a task\'s name/time text — applies '
                  'everywhere: Task view, List view, and Zone view.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                Row(
                  children: [
                    for (final size in TaskFontSize.values) ...[
                      if (size != TaskFontSize.values.first)
                        SizedBox(width: theme.spacingSm),
                      AppSelectableChip(
                        label: switch (size) {
                          TaskFontSize.sm => 'Small',
                          TaskFontSize.md => 'Medium',
                          TaskFontSize.lg => 'Large',
                        },
                        selected:
                            ref.watch(taskFontSizeSettingProvider) == size,
                        onTap: () => ref
                            .read(taskFontSizeSettingProvider.notifier)
                            .set(size),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
