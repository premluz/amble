import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/widgets/app_depth.dart';
import '../../shared/models/task.dart';
import 'selected_date_provider.dart';
import 'tasks_for_selected_day_provider.dart';

part 'day_task_motion.g.dart';

/// Which of the Day's tasks just arrived (to emerge from depth) and which
/// just left (to recede before they are gone).
@immutable
class DayTaskMotionState {
  const DayTaskMotionState({this.arriving = const {}, this.leaving = const {}});

  final Set<String> arriving;

  /// Tasks no longer on the day, kept (as they last were) until they have
  /// receded.
  final Map<String, Task> leaving;
}

/// Tracks the Day's tasks ABOVE the widgets that show them. Switching
/// between timeline and list view remounts every task, so "is this task
/// new" can't live in the task widgets (an entrance on mount replayed on
/// every switch — see `_DraggableTaskBlock`). A task arrives or leaves only
/// when the day's own list changes, however it happened (created,
/// scheduled here, deleted, moved away, undone). Changing the day itself
/// never animates. Arrivals are cleared once their frame is built, so a
/// later remount shows them at rest.
@Riverpod(keepAlive: true)
class DayTaskMotion extends _$DayTaskMotion {
  Map<String, Task> _known = const {};

  @override
  DayTaskMotionState build() {
    _known = _byId(ref.read(tasksForSelectedDayProvider));
    ref.listen(selectedDateProvider, (_, _) {
      _known = _byId(ref.read(tasksForSelectedDayProvider));
      state = const DayTaskMotionState();
    });
    ref.listen(tasksForSelectedDayProvider, (_, next) => _onTasks(next));
    return const DayTaskMotionState();
  }

  static Map<String, Task> _byId(List<Task> tasks) => {
    for (final task in tasks) task.id: task,
  };

  void _onTasks(List<Task> next) {
    final current = _byId(next);
    final arriving = {
      for (final id in current.keys)
        if (!_known.containsKey(id)) id,
    };
    final departed = {
      for (final entry in _known.entries)
        if (!current.containsKey(entry.key)) entry.key: entry.value,
    };
    _known = current;
    if (arriving.isEmpty && departed.isEmpty) return;
    state = DayTaskMotionState(
      arriving: arriving,
      leaving: {
        for (final entry in state.leaving.entries)
          if (!current.containsKey(entry.key)) entry.key: entry.value,
        ...departed,
      },
    );
    if (arriving.isEmpty) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (!ref.mounted || !identical(state.arriving, arriving)) return;
        state = DayTaskMotionState(leaving: state.leaving);
      })
      // Clearing must not depend on something else drawing a frame.
      ..ensureVisualUpdate();
  }

  /// A leaving task has receded: drop it for good.
  void settle(String taskId) {
    if (!state.leaving.containsKey(taskId)) return;
    state = DayTaskMotionState(
      arriving: state.arriving,
      leaving: {...state.leaving}..remove(taskId),
    );
  }

  /// The day's tasks as shown: the live ones plus any still receding, in
  /// time order (the layout relies on it).
  static List<Task> shown(List<Task> live, DayTaskMotionState motion) {
    if (motion.leaving.isEmpty) return live;
    final ids = {for (final task in live) task.id};
    return [
      ...live,
      for (final task in motion.leaving.values)
        if (!ids.contains(task.id)) task,
    ]..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }
}

/// Hands the Day's task motion down to the tasks both views draw. Placed
/// by the Day screen over its views; a [DayTaskPresence] outside it (a
/// block shown elsewhere, or alone in a test) is simply inert.
class DayTaskMotionScope extends InheritedWidget {
  const DayTaskMotionScope({
    super.key,
    required this.motion,
    required this.onSettled,
    required super.child,
  });

  final DayTaskMotionState motion;

  /// A leaving task has finished receding.
  final ValueChanged<String> onSettled;

  static DayTaskMotionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DayTaskMotionScope>();

  @override
  bool updateShouldNotify(DayTaskMotionScope oldWidget) =>
      !identical(motion, oldWidget.motion);
}

/// A Day task's presence: it emerges from depth when it just arrived and
/// recedes (untouchable) when it just left, then lets the day forget it.
/// [opensSpace] false for timeline tasks, which sit at their own time with
/// no neighbours to push; true for list rows, which open and close room.
class DayTaskPresence extends StatelessWidget {
  const DayTaskPresence({
    super.key,
    required this.taskId,
    required this.opensSpace,
    required this.child,
  });

  final String taskId;
  final bool opensSpace;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = DayTaskMotionScope.maybeOf(context);
    if (scope == null) return child;
    final leaving = scope.motion.leaving.containsKey(taskId);
    return IgnorePointer(
      ignoring: leaving,
      child: AppDepthPresence(
        present: !leaving,
        animateIn: scope.motion.arriving.contains(taskId),
        opensSpace: opensSpace,
        onExited: () => scope.onSettled(taskId),
        child: child,
      ),
    );
  }
}
