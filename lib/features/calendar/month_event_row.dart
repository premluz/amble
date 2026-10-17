import 'package:flutter/material.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/external_calendar_event.dart';
import '../timeline/external_event_block.dart';
import 'calendar_task_style.dart';
import 'events_on_day.dart';

/// A device-calendar event in a month cell, after the task rows: its
/// calendar's colour rail, start time (none for a whole-day event), title in
/// the secondary colour. A tap shows its details.
class MonthEventRow extends StatelessWidget {
  const MonthEventRow({super.key, required this.event});

  final ExternalCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return AppPressFeedback(
      onTap: () => showExternalCalendarEventInfo(
        context: context,
        theme: theme,
        event: event,
      ),
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingXs / 2),
        child: Row(
          children: [
            CalendarTaskRail(
              color:
                  event.sourceCalendarColor ??
                  TaskStateTokens.importedFill(theme),
              height: theme.spacingMd,
            ),
            SizedBox(width: theme.spacingXs),
            if (!isAllDay(event)) ...[
              Text(
                timelineClock(context, TimeOfDay.fromDateTime(event.start)),
                style: theme.textCaptionMono.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
              SizedBox(width: theme.spacingXs),
            ],
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textCaption.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
