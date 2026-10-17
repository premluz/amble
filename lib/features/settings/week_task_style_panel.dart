import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/providers/week_task_style_setting.dart';
import 'settings_panel.dart';

/// Appearance → "Week task style": pills or standard calendar blocks in the
/// desktop Week view. The caller shows it on the wide layout only.
class WeekTaskStylePanel extends ConsumerWidget {
  const WeekTaskStylePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final selected = ref.watch(weekTaskStyleSettingProvider);
    return SettingsPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week task style',
            style: theme.textBody.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: TypePrimitives.weightSemibold,
            ),
          ),
          SizedBox(height: theme.spacingXs),
          Text(
            'Pills, or standard calendar blocks as tall as the task, in the '
            'Week view on a larger screen.',
            style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
          ),
          SizedBox(height: theme.spacingSm),
          Row(
            children: [
              for (final style in WeekTaskStyle.values) ...[
                if (style != WeekTaskStyle.values.first)
                  SizedBox(width: theme.spacingSm),
                AppSelectableChip(
                  label: switch (style) {
                    WeekTaskStyle.pills => 'Pills',
                    WeekTaskStyle.blocks => 'Blocks',
                  },
                  selected: selected == style,
                  onTap: () => ref
                      .read(weekTaskStyleSettingProvider.notifier)
                      .set(style),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
