import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_tab_switch.dart';
import '../../core/widgets/app_option_switch_option.dart';
import '../timeline/selected_date_provider.dart';
import 'calendar_span.dart';

/// The wide layout's Days toolbar, after Notion Calendar's: the month and
/// year, then how many days to show (Day / Week / Month), Today, and
/// previous / next by that span.
class DesktopCalendarToolbar extends ConsumerWidget {
  const DesktopCalendarToolbar({super.key});

  static const _spans = [
    AppOptionSwitchOption(value: CalendarSpan.day, label: 'Day'),
    AppOptionSwitchOption(value: CalendarSpan.week, label: 'Week'),
    AppOptionSwitchOption(value: CalendarSpan.month, label: 'Month'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final date = ref.watch(selectedDateProvider);
    final span = ref.watch(calendarSpanProvider);
    final dates = ref.read(selectedDateProvider.notifier);
    void step(int direction) => dates.goTo(stepBySpan(date, span, direction));
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingScreenPadding,
        vertical: theme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
            ),
          ),
          SizedBox(
            width: CalendarGridTokens.spanSwitchWidth,
            child: AppTabSwitch<CalendarSpan>(
              options: _spans,
              value: span,
              onChanged: ref.read(calendarSpanProvider.notifier).set,
            ),
          ),
          SizedBox(width: theme.spacingSm),
          AppButton(
            label: 'Today',
            variant: AppButtonVariant.secondary,
            shape: AppButtonShape.pill,
            onPressed: dates.goToToday,
          ),
          SizedBox(width: theme.spacingXs),
          AppButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: 'Previous',
            variant: AppButtonVariant.ghost,
            shape: AppButtonShape.circle,
            onPressed: () => step(-1),
          ),
          AppButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: 'Next',
            variant: AppButtonVariant.ghost,
            shape: AppButtonShape.circle,
            onPressed: () => step(1),
          ),
        ],
      ),
    );
  }
}
