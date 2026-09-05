import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import 'duration_label.dart';

/// How long a gap between tasks has to be before it earns its own block on
/// the Timeline. Requested directly: "no indicator for small/normal gaps
/// (today's behaviour, unchanged), a labeled, size-appropriate compact
/// block only for large gaps" — proposed as a starting point, adjustable.
/// Hardcoded for now rather than a Settings control (flagged as follow-up
/// work, not part of this pass) — kept as one named constant so the whole
/// app has a single source of truth for "large" regardless.
const freeWindowThreshold = Duration(hours: 2);

/// A single maximal free interval on a day — nothing scheduled anywhere
/// (any overlap column) between [start] and [end].
class FreeWindow {
  const FreeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Finds every gap of at least [freeWindowThreshold] between consecutive
/// tasks in [tasks] — NOT gaps before the first task or after the last,
/// since those edges are already bounded by
/// `_DayTimelineState._visibleRange`'s own padding and don't read as a
/// genuine "free window" the way a gap between two real commitments does.
///
/// Ignores overlap columns entirely: a window only counts as free if
/// NOTHING is scheduled anywhere in that interval, matching the mockup's
/// full-width block. [tasks] does not need to be pre-sorted.
///
/// [minPillMinutes] is the shortest a task's PILL can ever render as, in
/// minutes of equivalent screen space — [TaskCapsuleBlock] floors a
/// pill's height at its badge size, so a very short task (e.g. 5 minutes)
/// still occupies real pixels well past its scheduled end time. Fixed
/// directly: without this floor, a free window computed from raw
/// scheduled times could start exactly where a short task's SCHEDULED
/// end was, while the task's actual rendered pill still extended further
/// down — the block and the pill then visually overlapped. Callers pass
/// `_pillWidth(theme) / pixelsPerMinute` (mirroring
/// `timeline_screen.dart`'s own `_pillHeight` floor) so the two stay in
/// sync.
List<FreeWindow> findFreeWindows(
  List<Task> tasks, {
  double minPillMinutes = 0,
}) {
  if (tasks.length < 2) return const [];

  final sorted = [...tasks]
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  DateTime effectiveEnd(Task task) {
    final scheduledEnd = task.scheduledAt!.add(
      Duration(minutes: task.durationMinutes!),
    );
    final flooredEnd = task.scheduledAt!.add(
      Duration(minutes: minPillMinutes.ceil()),
    );
    return flooredEnd.isAfter(scheduledEnd) ? flooredEnd : scheduledEnd;
  }

  final windows = <FreeWindow>[];
  var latestEnd = effectiveEnd(sorted.first);

  for (final task in sorted.skip(1)) {
    final start = task.scheduledAt!;
    final end = effectiveEnd(task);
    // A task starting before the running end doesn't open a gap — it
    // either overlaps or is fully nested inside what came before.
    if (start.isAfter(latestEnd)) {
      final gap = start.difference(latestEnd);
      if (gap >= freeWindowThreshold) {
        windows.add(FreeWindow(start: latestEnd, end: start));
      }
    }
    if (end.isAfter(latestEnd)) latestEnd = end;
  }

  return windows;
}

/// The subtle block rendered inside a [FreeWindow] large enough to earn
/// one. Aligned with task NAMES, not the icon-pill column — corrected
/// directly: the caller (`timeline_screen.dart`) indents [left] past
/// where the pill column ends, and insets [top]/[height] so the block
/// never touches the task immediately before or after it. No icon, no
/// pill, no shadow — just a quiet labeled rectangle.
class FreeWindowBlock extends StatelessWidget {
  const FreeWindowBlock({
    super.key,
    required this.theme,
    required this.window,
    required this.top,
    required this.height,
    required this.left,
    required this.onTap,
  });

  final AmbleTheme theme;
  final FreeWindow window;
  final double top;
  final double height;

  /// Where the block starts horizontally — the caller passes
  /// `hourGutterWidth + pillWidth + spacingSm`, aligning this with where a
  /// task's own title/time text starts, past its icon-pill column.
  final double left;

  /// Opens the create-task flow, seeded to start at [FreeWindow.start] —
  /// requested directly: "tapping on text opens create task (start hour
  /// default to beginning of that window)."
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorFreeWindow,
            borderRadius: BorderRadius.circular(theme.radiusXl),
          ),
          child: Text(
            '${formatDurationLabel(window.duration.inMinutes)} window, add '
            'a task.',
            textAlign: TextAlign.center,
            style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
          ),
        ),
      ),
    );
  }
}
