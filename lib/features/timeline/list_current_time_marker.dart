import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../../core/wall_clock_watcher.dart';
import 'current_time_indicator.dart';

/// Where the List view's "now" marker goes in a start-ordered row list:
/// just after every row that has already started — requested directly:
/// the current time "will always be between the tasks... never overlap a
/// task", and a task already in progress stays ABOVE the line (confirmed
/// via AskUserQuestion). A row with no start (an unscheduled zone-only
/// task) counts as not started.
///
/// [rows] must already be sorted by start, so the started rows are a
/// prefix and the answer is the first row that hasn't started yet.
int nowMarkerIndex<T>(
  List<T> rows,
  DateTime? Function(T row) startOf,
  DateTime now,
) {
  final index = rows.indexWhere((row) {
    final start = startOf(row);
    return start == null || start.isAfter(now);
  });
  return index == -1 ? rows.length : index;
}

/// The List view's own "now" marker — the same [CurrentTimeMarker] the
/// spatial view draws, but as its own row between tasks instead of at a
/// minute-exact y (the List view has no time axis).
///
/// Its time pill escapes left into the list's hour-label column, the same
/// way `ZoneRowTimeLabel` pulls each row's time out of its padding, so
/// "now" reads as one more entry in that column. The line still runs to
/// the row's own right edge.
class ListCurrentTimeMarker extends StatelessWidget {
  const ListCurrentTimeMarker({
    super.key,
    required this.time,
    required this.labelShift,
  });

  final DateTime time;

  /// Horizontal offset from this marker's own left edge to the hour-label
  /// column — `zoneRowTimeLabelEdgeInset` minus every padding layer above
  /// the marker. Negative pulls the pill left, out of that padding.
  final double labelShift;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => OverflowBox(
        minWidth: constraints.maxWidth - labelShift,
        maxWidth: constraints.maxWidth - labelShift,
        // Right-aligned so the widened row grows LEFTWARD only: the pill
        // lands in the label column while the line's end stays put.
        alignment: Alignment.centerRight,
        fit: OverflowBoxFit.deferToChild,
        child: CurrentTimeMarker(time: time, pillSizesRow: true),
      ),
    );
  }
}

/// Rebuilds [builder] with the current time on each wall-clock minute (and
/// on a system time change or app resume) — the same [WallClockWatcher]
/// the spatial view's [CurrentTimeIndicator] uses, so both views move on
/// together.
class CurrentMinuteBuilder extends StatefulWidget {
  const CurrentMinuteBuilder({
    super.key,
    required this.now,
    required this.builder,
  });

  /// Where "now" comes from — the Timeline's clock provider, so tests can
  /// pin the time.
  final DateTime Function() now;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<CurrentMinuteBuilder> createState() => _CurrentMinuteBuilderState();
}

class _CurrentMinuteBuilderState extends State<CurrentMinuteBuilder> {
  late DateTime _now = widget.now();

  late final _clock = WallClockWatcher(
    now: () => widget.now(),
    onChange: () {
      if (mounted) setState(() => _now = widget.now());
    },
  );

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
