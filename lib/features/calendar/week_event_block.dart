import 'package:flutter/material.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/external_calendar_event.dart';
import '../timeline/external_event_block.dart';

/// A device-calendar event as a standard block in the week grid (blocks
/// style): the neutral imported tone, since an event has no Amble label.
/// Read-only; a tap shows the event's details.
class WeekEventCard extends StatelessWidget {
  const WeekEventCard({super.key, required this.event});

  final ExternalCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final fill = TaskStateTokens.importedFill(theme);
    final radius = BorderRadius.circular(theme.radiusSm);
    return AppPressFeedback(
      onTap: () => _showInfo(context, theme, event),
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TaskStateTokens.blockBackground(theme, fill),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: event.sourceCalendarColor ?? fill,
                child: const SizedBox(width: CalendarGridTokens.railWidth),
              ),
              Expanded(
                child: ClipRect(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacingXs,
                      vertical: theme.spacingXs / 2,
                    ),
                    child: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTaskTitle.copyWith(
                        color: theme.colorTextSecondary,
                        fontWeight: TaskStateTokens.titleWeight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A device-calendar event in the week's pills style: a neutral capsule as
/// tall as the event at the pill's width, with [WeekEventText] beside it.
class WeekEventPill extends StatelessWidget {
  const WeekEventPill({super.key, required this.event, required this.height});

  final ExternalCalendarEvent event;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return AppPressFeedback(
      onTap: () => _showInfo(context, theme, event),
      borderRadius: BorderRadius.circular(theme.radiusPillFull),
      child: Container(
        width: theme.sizeTaskBadge,
        height: height < theme.sizeTaskBadge ? theme.sizeTaskBadge : height,
        decoration: BoxDecoration(
          color: TaskStateTokens.importedFill(theme),
          borderRadius: BorderRadius.circular(theme.radiusPillFull),
        ),
      ),
    );
  }
}

/// An event's title beside its pill.
class WeekEventText extends StatelessWidget {
  const WeekEventText({super.key, required this.event});

  final ExternalCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return GestureDetector(
      onTap: () => _showInfo(context, theme, event),
      child: SizedBox(
        height: CalendarGridTokens.weekTextRowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTaskTitle.copyWith(
              color: theme.colorTextSecondary,
              fontWeight: TaskStateTokens.titleWeight,
            ),
          ),
        ),
      ),
    );
  }
}

void _showInfo(
  BuildContext context,
  AmbleTheme theme,
  ExternalCalendarEvent event,
) =>
    showExternalCalendarEventInfo(context: context, theme: theme, event: event);
