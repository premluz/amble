import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/scheduled_block.dart';
import '../../shared/services/overlap_cluster.dart';
import 'events_on_day.dart';
import 'week_drag.dart';

typedef WeekSlot = ({int lane, int count});

/// Builds an item's widget, given the height it is drawn at.
typedef WeekItemBuilder = Widget Function(ScheduledBlock item, double height);

/// Where one week day's items sit: by time on [day] at [hourHeight], side
/// by side where they overlap, in a column [width] wide. Lanes come from
/// the items as they rest, so a drag never reshuffles its neighbours.
class WeekDayLayout {
  WeekDayLayout({
    required this.theme,
    required this.day,
    required this.hourHeight,
    required this.width,
    required List<ScheduledBlock> items,
  }) {
    for (final cluster in detectOverlapClusters(items)) {
      final assigned = clusterLanes(cluster);
      final count = assigned.reduce(math.max) + 1;
      _widest = math.max(_widest, count);
      for (var i = 0; i < cluster.blocks.length; i++) {
        _slots[cluster.blocks[i].id] = (lane: assigned[i], count: count);
      }
    }
  }

  final AmbleTheme theme;
  final DateTime day;
  final double hourHeight;
  final double width;
  final _slots = <String, WeekSlot>{};
  var _widest = 1;

  double get _inset => theme.spacingXs / 2;
  double get _pitch => theme.sizeTaskBadge + theme.spacingSm;
  double get _textLeft => _inset + _widest * _pitch;

  double _y(int minutes) => minutes * hourHeight / Duration.minutesPerHour;

  double topAt(DateTime start) => _y(minutesOnDay(start, day));

  double heightOf(DateTime start, int minutes) =>
      _y(minutesOnDay(start.add(Duration(minutes: minutes)), day)) -
      topAt(start);

  double _height(ScheduledBlock item) => heightOf(
    item.scheduledStart,
    item.scheduledEnd.difference(item.scheduledStart).inMinutes,
  );

  /// Standard calendar blocks, overlapping ones sharing the width equally.
  List<Widget> blocks(List<ScheduledBlock> items, WeekItemBuilder build) => [
    for (final item in items)
      _block(
        ValueKey(item.id),
        top: topAt(item.scheduledStart),
        height: _height(item),
        slot: _slots[item.id] ?? (lane: 0, count: 1),
        child: (height) => build(item, height),
      ),
  ];

  /// [drag]'s landing spot as a block across the whole column.
  Widget blockPreview(WeekDrag drag, WeekItemBuilder build) => _block(
    const ValueKey(#weekDragPreview),
    top: topAt(drag.start),
    height: heightOf(drag.start, drag.durationMinutes),
    slot: (lane: 0, count: 1),
    child: (height) => IgnorePointer(child: build(drag.item, height)),
  );

  Widget _block(
    Key key, {
    required double top,
    required double height,
    required WeekSlot slot,
    required Widget Function(double height) child,
  }) {
    final laneWidth = (width - _inset * 2) / slot.count;
    final drawn = math.max(
      CalendarGridTokens.weekBlockMinHeight,
      height - CalendarGridTokens.weekBlockGap,
    );
    return Positioned(
      key: key,
      top: top,
      left: _inset + slot.lane * laneWidth,
      width: math.max(0, laneWidth - CalendarGridTokens.weekBlockGap),
      height: drawn,
      child: child(drawn),
    );
  }

  /// Pills side by side at pill width where items overlap, as on the Day
  /// screen; every item's text after the widest group of pills, at its own
  /// time, pushed down only if an earlier row would cover it.
  List<Widget> pills(
    List<ScheduledBlock> items, {
    required double textRowHeight,
    required WeekItemBuilder pill,
    required WeekItemBuilder text,
  }) {
    var textFloor = 0.0;
    final widgets = <Widget>[];
    for (final item in items) {
      final y = topAt(item.scheduledStart);
      final lane = _slots[item.id]?.lane ?? 0;
      widgets.add(
        Positioned(
          key: ValueKey(item.id),
          top: y,
          left: _inset + lane * _pitch,
          child: pill(item, _height(item)),
        ),
      );
      final textTop = math.max(y, textFloor);
      textFloor = textTop + textRowHeight;
      widgets.add(_text(ValueKey('${item.id}-text'), textTop, text(item, 0)));
    }
    return widgets;
  }

  /// [drag]'s landing spot as a pill in the first lane, with its text.
  List<Widget> pillPreview(
    WeekDrag drag, {
    required WeekItemBuilder pill,
    required WeekItemBuilder text,
  }) {
    final top = topAt(drag.start);
    return [
      Positioned(
        key: const ValueKey(#weekDragPreviewPill),
        top: top,
        left: _inset,
        child: IgnorePointer(
          child: pill(drag.item, heightOf(drag.start, drag.durationMinutes)),
        ),
      ),
      _text(
        const ValueKey(#weekDragPreviewText),
        top,
        IgnorePointer(child: text(drag.item, 0)),
      ),
    ];
  }

  Widget _text(Key key, double top, Widget child) => Positioned(
    key: key,
    top: top,
    left: _textLeft,
    width: math.max(0, width - _textLeft),
    child: child,
  );
}
