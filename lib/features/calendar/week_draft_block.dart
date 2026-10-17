import 'package:flutter/material.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../core/widgets/glass_pill_surface.dart';
import '../../core/widgets/selected_pill_border.dart';
import '../task_detail/draft_form_link.dart';

/// The new task being drawn in the week (blocks style): an accent block
/// with the draft's name and range, until it is saved from the side panel.
class WeekDraftCard extends StatelessWidget {
  const WeekDraftCard({super.key, required this.start, required this.minutes});

  final DateTime start;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final radius = BorderRadius.circular(theme.radiusSm);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskStateTokens.blockBackground(theme, theme.colorAccent),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: theme.colorAccent,
              child: const SizedBox(width: CalendarGridTokens.railWidth),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacingXs,
                  vertical: theme.spacingXs / 2,
                ),
                child: WeekDraftText(start: start, minutes: minutes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The draft in pills style: the Day screen's own draft pill (a glass pill
/// with the selected border, `PendingTaskPill`) as tall as the draft.
class WeekDraftPill extends StatelessWidget {
  const WeekDraftPill({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final width = theme.sizeTaskBadge;
    return SizedBox(
      width: width,
      height: height < width ? width : height,
      child: SelectedPillBorder(
        theme: theme,
        contentRadius: BorderRadius.circular(theme.radiusPill),
        fillColor: null,
        child: GlassPillSurface(
          theme: theme,
          width: width,
          height: height < width ? width : height,
        ),
      ),
    );
  }
}

/// The draft's name and start-end range. A short draft clips its second
/// line rather than overflowing.
class WeekDraftText extends StatelessWidget {
  const WeekDraftText({super.key, required this.start, required this.minutes});

  final DateTime start;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final from = timelineClock(context, TimeOfDay.fromDateTime(start));
    final to = timelineClock(
      context,
      TimeOfDay.fromDateTime(start.add(Duration(minutes: minutes))),
    );
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxHeight: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DraftFormLink.defaultName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTaskTitle.copyWith(
                color: theme.colorTextSecondary,
                fontWeight: TaskStateTokens.titleWeight,
              ),
            ),
            Text(
              '$from - $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TaskStateTokens.timeUnderTitleStyle(theme),
            ),
          ],
        ),
      ),
    );
  }
}
