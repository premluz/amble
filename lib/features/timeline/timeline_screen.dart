import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../task_detail/task_detail_sheet.dart';
import 'current_time_indicator.dart';
import 'day_navigation_row.dart';
import 'hour_markers.dart';
import 'selected_date_provider.dart';
import 'task_capsule_block.dart';
import 'tasks_for_selected_day_provider.dart';

const _startHour = 6;
const _endHour = 22;
const _pixelsPerMinute = 1.5;
const _hourGutterWidth = 56.0;

/// [TaskCapsuleBlock]'s badge is `spacingXl * 1.5` per its own
/// implementation; mirrored here (not imported — the badge size is an
/// internal layout detail, not part of its public API) so this screen can
/// align the badge's vertical *center*, not its top edge, with the task's
/// scheduled-time row. See docs/DECISIONS.md.
double _badgeSize(AmbleTheme theme) => theme.spacingXl * 1.5;

/// The Timeline day view — hour markers, tasks for the selected day
/// positioned by [Task.scheduledAt]/[Task.durationMinutes], a live
/// current-time indicator, and simple day navigation. Wired to
/// [tasksForSelectedDayProvider] (real provider data, Phase 1 + this
/// session), not seeded data — see timeline_capsule_preview.dart for the
/// separate dev-scaffold preview.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref.watch(tasksForSelectedDayProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final dayNotifier = ref.read(selectedDateProvider.notifier);
    final taskNotifier = ref.read(taskListProvider.notifier);

    return Container(
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: theme.spacingMd),
                const DayNavigationRow(),
                SizedBox(height: theme.spacingSm),
                const Center(child: TodayButton()),
                SizedBox(height: theme.spacingSm),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < 0) {
                        dayNotifier.goToNextDay();
                      } else if (velocity > 0) {
                        dayNotifier.goToPreviousDay();
                      }
                    },
                    child: tasks.isEmpty
                        ? _EmptyDayState(theme: theme)
                        : _DayTimeline(
                            tasks: tasks,
                            theme: theme,
                            onTaskTap: (task) =>
                                showTaskDetailSheet(context, task: task),
                            onToggleComplete: taskNotifier.toggleComplete,
                            onReschedule: (task, newScheduledAt) => taskNotifier
                                .rescheduleTask(task, newScheduledAt),
                          ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: theme.spacingLg,
              bottom: theme.spacingLg,
              child: AppIconButton(
                icon: Icons.add_rounded,
                onPressed: () => showTaskDetailSheet(
                  context,
                  initialScheduledAt: DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    DateTime.now().hour,
                    DateTime.now().minute,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _TaskCallback = void Function(Task task);
typedef _RescheduleCallback = void Function(Task task, DateTime newScheduledAt);

class _DayTimeline extends StatefulWidget {
  const _DayTimeline({
    required this.tasks,
    required this.theme,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final List<Task> tasks;
  final AmbleTheme theme;
  final _TaskCallback onTaskTap;
  final _TaskCallback onToggleComplete;
  final _RescheduleCallback onReschedule;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open the day view scrolled to roughly the current time, not 6am,
    // so "now" is visible without the user having to scroll first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final minutesSinceStart = (now.hour - _startHour) * 60 + now.minute;
      final target =
          (minutesSinceStart * _pixelsPerMinute) -
          (_scrollController.position.viewportDimension / 2);
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tasks = widget.tasks;
    final dayHeight = (_endHour - _startHour) * 60 * _pixelsPerMinute;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingScreenPadding,
        vertical: theme.spacingMd,
      ),
      child: SizedBox(
        height: dayHeight,
        child: Stack(
          children: [
            const HourMarkers(
              startHour: _startHour,
              endHour: _endHour,
              pixelsPerMinute: _pixelsPerMinute,
            ),
            for (final task in tasks)
              _DraggableTaskBlock(
                key: ValueKey(task.id),
                task: task,
                theme: theme,
                baseTop:
                    _minutesSinceStart(task.scheduledAt) * _pixelsPerMinute -
                    _badgeSize(theme) / 2,
                left: _hourGutterWidth,
                onTap: () => widget.onTaskTap(task),
                onToggleComplete: () => widget.onToggleComplete(task),
                onReschedule: (newScheduledAt) =>
                    widget.onReschedule(task, newScheduledAt),
              ),
            const CurrentTimeIndicator(
              startHour: _startHour,
              pixelsPerMinute: _pixelsPerMinute,
            ),
          ],
        ),
      ),
    );
  }

  double _minutesSinceStart(DateTime scheduledAt) =>
      ((scheduledAt.hour - _startHour) * 60 + scheduledAt.minute).toDouble();
}

/// Wraps a [TaskCapsuleBlock] with vertical drag-to-reschedule. Tracks a
/// live drag offset for visual feedback while dragging; on release, snaps
/// to the nearest 5-minute increment and calls [onReschedule] — which is
/// the only place a reschedule actually gets written (via
/// [TaskList.rescheduleTask]).
class _DraggableTaskBlock extends StatefulWidget {
  const _DraggableTaskBlock({
    super.key,
    required this.task,
    required this.theme,
    required this.baseTop,
    required this.left,
    required this.onTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final Task task;
  final AmbleTheme theme;
  final double baseTop;
  final double left;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final ValueChanged<DateTime> onReschedule;

  @override
  State<_DraggableTaskBlock> createState() => _DraggableTaskBlockState();
}

class _DraggableTaskBlockState extends State<_DraggableTaskBlock> {
  double _dragOffset = 0;
  bool _isDragging = false;

  static const _snapMinutes = 5;

  @override
  Widget build(BuildContext context) {
    final top = widget.baseTop + _dragOffset;

    return Positioned(
      top: top,
      left: widget.left,
      right: 0,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _isDragging = true),
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffset += details.delta.dy);
        },
        onVerticalDragEnd: (_) {
          final minutesDelta =
              (_dragOffset / _pixelsPerMinute / _snapMinutes).round() *
              _snapMinutes;
          setState(() {
            _isDragging = false;
            _dragOffset = 0;
          });
          if (minutesDelta == 0) return;
          final newScheduledAt = widget.task.scheduledAt.add(
            Duration(minutes: minutesDelta),
          );
          widget.onReschedule(newScheduledAt);
        },
        child: Opacity(
          opacity: _isDragging ? 0.75 : 1.0,
          child: TaskCapsuleBlock(
            task: widget.task,
            pixelsPerMinute: _pixelsPerMinute,
            onTap: widget.onTap,
            onToggleComplete: widget.onToggleComplete,
          ),
        ),
      ),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: theme.spacingXl * 1.5,
              color: theme.colorTextSecondary,
            ),
            SizedBox(height: theme.spacingMd),
            Text(
              'Nothing scheduled today',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
