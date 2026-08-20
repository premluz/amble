import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import 'selected_date_provider.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Simple day-navigation row: previous/next day, the selected date, and a
/// "Today" jump button (shown only when not already on today). A basic
/// version of the reference UI's week strip — full week-strip polish is a
/// later session, per the Phase 3 work order.
class DayNavigationRow extends ConsumerWidget {
  const DayNavigationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final selectedDate = ref.watch(selectedDateProvider);
    final notifier = ref.read(selectedDateProvider.notifier);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacingScreenPadding),
      child: Row(
        children: [
          IconButton(
            onPressed: notifier.goToPreviousDay,
            icon: const Icon(Icons.chevron_left_rounded),
            color: theme.colorTextSecondary,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _weekdayNames[selectedDate.weekday - 1],
                  style: theme.textLabel.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                Text(
                  '${_monthNames[selectedDate.month - 1]} ${selectedDate.day}',
                  style: theme.textTitle.copyWith(
                    color: theme.colorTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: notifier.goToNextDay,
            icon: const Icon(Icons.chevron_right_rounded),
            color: theme.colorTextSecondary,
          ),
        ],
      ),
    );
  }
}

/// Small "Today" jump button — separate widget so it can be omitted from
/// the row entirely (via a conditional) rather than rendered disabled.
class TodayButton extends ConsumerWidget {
  const TodayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = _isSameDay(selectedDate, DateTime.now());
    if (isToday) return const SizedBox.shrink();

    return AppButton(
      label: 'Today',
      variant: AppButtonVariant.secondary,
      onPressed: ref.read(selectedDateProvider.notifier).goToToday,
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
