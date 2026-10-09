import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/providers/calendar_grid_lines_setting.dart';
import 'settings_panel.dart';

/// Appearance → "Calendar grid lines": the faint lines splitting days and
/// hours in the desktop Week and Month views.
class CalendarGridLinesPanel extends ConsumerWidget {
  const CalendarGridLinesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final setting = ref.read(calendarGridLinesSettingProvider.notifier);
    return SettingsPanel(
      theme: theme,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar grid lines',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: TypePrimitives.weightSemibold,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  'Faint lines between days and hours in the Week and '
                  'Month views on a larger screen.',
                  style: theme.textCaption.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacingSm),
          AppSwitch(
            value: ref.watch(calendarGridLinesSettingProvider),
            onChanged: setting.set,
          ),
        ],
      ),
    );
  }
}
