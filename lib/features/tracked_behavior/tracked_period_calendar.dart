import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';
import 'tracked_calendar_period.dart';

const _flingVelocityThreshold = 400.0;

/// A fixed-height Tracked period header and horizontal period navigator.
/// Its caption aligns with Day's collapsed calendar label; the reserved
/// space below it keeps the following content at the same vertical position
/// without showing an expansion affordance.
class TrackedPeriodCalendar extends StatefulWidget {
  const TrackedPeriodCalendar({
    super.key,
    required this.viewMode,
    required this.bodyBuilder,
    this.initialDate,
  });

  final TrackedBehaviorViewMode viewMode;
  final Widget Function(BuildContext context, DateTime periodDate) bodyBuilder;
  final DateTime? initialDate;

  @override
  State<TrackedPeriodCalendar> createState() => _TrackedPeriodCalendarState();
}

class _TrackedPeriodCalendarState extends State<TrackedPeriodCalendar> {
  late DateTime _periodDate;
  double _dragDistance = 0;

  bool get _isViewingTodayPeriod =>
      TrackedCalendarPeriod.start(_periodDate, widget.viewMode) ==
      TrackedCalendarPeriod.start(DateTime.now(), widget.viewMode);

  void _goToToday() {
    final today = DateTime.now();
    setState(() => _periodDate = DateTime(today.year, today.month, today.day));
  }

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate ?? DateTime.now();
    _periodDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
  }

  void _onHorizontalDragEnd(DragEndDetails details, AmbleTheme theme) {
    final distanceIsEnough = _dragDistance.abs() >= theme.spacingMinTapTarget;
    final velocity = details.primaryVelocity ?? 0;
    final isFling = velocity.abs() >= _flingVelocityThreshold;
    if (!distanceIsEnough && !isFling) return;

    final direction = distanceIsEnough
        ? (_dragDistance < 0 ? 1 : -1)
        : (velocity < 0 ? 1 : -1);
    setState(() {
      _periodDate = TrackedCalendarPeriod.shift(
        _periodDate,
        widget.viewMode,
        direction,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, theme),
      onHorizontalDragCancel: () => _dragDistance = 0,
      child: Column(
        children: [
          _TrackedPeriodHeading(
            theme: theme,
            viewMode: widget.viewMode,
            date: _periodDate,
            showToday: !_isViewingTodayPeriod,
            onToday: _goToToday,
          ),
          Expanded(child: widget.bodyBuilder(context, _periodDate)),
        ],
      ),
    );
  }
}

class _TrackedPeriodHeading extends StatelessWidget {
  const _TrackedPeriodHeading({
    required this.theme,
    required this.viewMode,
    required this.date,
    required this.showToday,
    required this.onToday,
  });

  final AmbleTheme theme;
  final TrackedBehaviorViewMode viewMode;
  final DateTime date;
  final bool showToday;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label = TrackedCalendarPeriod.label(date, viewMode);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        0,
        theme.spacingScreenPadding,
        theme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: theme.motionFast,
                    switchInCurve: theme.curveStandard,
                    switchOutCurve: theme.curveStandard,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...previousChildren, ?currentChild],
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: theme.textBody,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !showToday,
                child: AnimatedOpacity(
                  opacity: showToday ? 1 : 0,
                  duration: theme.motionNormal,
                  curve: theme.curveStandard,
                  child: AppPressFeedback(
                    onTap: onToday,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacingXs,
                        vertical: theme.spacingXs / 2,
                      ),
                      child: Text(
                        'Today',
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Day's collapsed accordion reserves spacingXs plus its 4px grip.
          // Keep that footprint while omitting a misleading expansion affordance.
          SizedBox(height: theme.spacingXs * 2),
        ],
      ),
    );
  }
}
