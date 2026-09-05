import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/collapsed_stack_layout.dart';

CollapsedStackRow _row(String id, DateTime start, double height) =>
    CollapsedStackRow(ids: [id], start: start, height: height);

void main() {
  _labelTopsTests();
  group('computeCollapsedStackTops', () {
    test('a lone task row starts at 0', () {
      final tops = computeCollapsedStackTops(
        taskRows: [_row('t1', DateTime(2026, 9, 4, 9), 40)],
        externalEventRows: const [],
        gap: 8,
      );
      expect(tops, {'t1': 0.0});
    });

    test('consecutive task rows stack with the gap between them', () {
      final tops = computeCollapsedStackTops(
        taskRows: [
          _row('t1', DateTime(2026, 9, 4, 9), 40),
          _row('t2', DateTime(2026, 9, 4, 10), 60),
        ],
        externalEventRows: const [],
        gap: 8,
      );
      expect(tops['t1'], 0.0);
      expect(tops['t2'], 48.0); // 0 + 40 + 8
    });

    // Regression test for the real bug, reported directly: "tasks on list
    // view should not overlap (the app tasks with the imported tasks
    // should be one by one)." Before this function existed, task rows were
    // positioned in one independent pass and external events in a SECOND
    // pass that only read the already-fixed task positions — an event
    // landing chronologically between two tasks could never push the
    // later task down, so it just visually overlapped it.
    test('an external event landing chronologically BETWEEN two tasks pushes '
        'the later task down instead of overlapping it', () {
      final tops = computeCollapsedStackTops(
        taskRows: [
          _row('t1', DateTime(2026, 9, 4, 9), 40),
          _row('t2', DateTime(2026, 9, 4, 11), 40),
        ],
        externalEventRows: [
          _row('e1', DateTime(2026, 9, 4, 10), 100), // Taller than a task.
        ],
        gap: 8,
      );

      expect(tops['t1'], 0.0);
      expect(tops['e1'], 48.0); // 0 + 40 + 8, right after t1.
      // t2 must start at or after e1's own bottom edge — the actual bug:
      // t2 previously kept its independently-computed top regardless of
      // e1 landing in between, so this would have failed at 48.0 instead.
      expect(tops['t2'], greaterThanOrEqualTo(tops['e1']! + 100 + 8));
      expect(tops['t2'], 156.0); // 48 + 100 + 8
    });

    test('every row is chronologically ordered and non-overlapping — no '
        'row starts before the previous row\'s bottom edge, whether it is '
        'a task or an external event', () {
      final taskRows = [
        _row('t1', DateTime(2026, 9, 4, 9), 30),
        _row('t2', DateTime(2026, 9, 4, 9, 45), 30),
      ];
      final eventRows = [
        _row('e1', DateTime(2026, 9, 4, 9, 15), 50),
        _row('e2', DateTime(2026, 9, 4, 12), 20),
      ];
      final tops = computeCollapsedStackTops(
        taskRows: taskRows,
        externalEventRows: eventRows,
        gap: 8,
      );

      final heightsById = {
        for (final row in [...taskRows, ...eventRows])
          row.ids.single: row.height,
      };
      final sortedIds = [...tops.keys]
        ..sort((a, b) => tops[a]!.compareTo(tops[b]!));

      for (var i = 1; i < sortedIds.length; i++) {
        final previousId = sortedIds[i - 1];
        final previousBottom = tops[previousId]! + heightsById[previousId]!;
        expect(
          tops[sortedIds[i]]!,
          greaterThanOrEqualTo(previousBottom),
          reason: '${sortedIds[i]} overlaps $previousId',
        );
      }
    });

    test('overlapping tasks sharing one row (same ids list) share one top', () {
      final tops = computeCollapsedStackTops(
        taskRows: [
          CollapsedStackRow(
            ids: ['t1', 't2'],
            start: DateTime(2026, 9, 4, 9),
            height: 60,
          ),
        ],
        externalEventRows: const [],
        gap: 8,
      );
      expect(tops['t1'], tops['t2']);
    });

    test('empty input returns an empty map', () {
      final tops = computeCollapsedStackTops(
        taskRows: const [],
        externalEventRows: const [],
        gap: 8,
      );
      expect(tops, isEmpty);
    });
  });

  // Regression test for a real bug, reported directly from a screenshot:
  // a clustered row's stacking-cursor height used to be just its tallest
  // member pill's own badge-floored height — a couple of small icons'
  // worth of space — while the cluster's real rendered content (every
  // member's own title+time line, inside its own padding) is far taller.
  group('collapsedClusterHeight', () {
    test('one member is one line plus padding on both edges, no inter-row '
        'gap', () {
      expect(
        collapsedClusterHeight(
          memberCount: 1,
          lineHeight: 20,
          lineGap: 4,
          verticalPadding: 8,
        ),
        20 + 8 * 2,
      );
    });

    test('each extra member adds a line plus one inter-row gap', () {
      expect(
        collapsedClusterHeight(
          memberCount: 3,
          lineHeight: 20,
          lineGap: 4,
          verticalPadding: 8,
        ),
        20 * 3 + 4 * 2 + 8 * 2,
      );
    });

    test('is far taller than a single small pill for a real multi-member '
        'cluster — the actual bug this exists to prevent', () {
      const pillHeight = 20.0; // a badge-size-floored pill, e.g. an icon.
      final clusterHeight = collapsedClusterHeight(
        memberCount: 2,
        lineHeight: 24,
        lineGap: 4,
        verticalPadding: 8,
      );
      expect(clusterHeight, greaterThan(pillHeight));
    });
  });
}

/// Task-name labels align to their own pill's icon, stacking only when
/// they would otherwise collide — requested directly.
void _labelTopsTests() {
  group('computeLabelTops', () {
    test('a lone label sits exactly at its own icon', () {
      final tops = computeLabelTops(
        anchors: const [LabelAnchor(id: 'a', preferredTop: 120, height: 20)],
        gap: 4,
      );
      expect(tops['a'], 120);
    });

    test('two well-separated labels BOTH keep their exact icon alignment', () {
      final tops = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          LabelAnchor(id: 'b', preferredTop: 300, height: 20),
        ],
        gap: 4,
      );
      expect(tops['a'], 100);
      expect(tops['b'], 300);
    });

    test('two labels at the SAME time stack one after the other', () {
      final tops = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          LabelAnchor(id: 'b', preferredTop: 100, height: 20),
        ],
        gap: 4,
      );
      expect(tops['a'], 100);
      // Pushed clear of a: 100 + 20 + 4.
      expect(tops['b'], 124);
    });

    test('a label only TOO CLOSE is pushed just clear, not fully stacked', () {
      final tops = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          // Would overlap a (which ends at 120) by 10px.
          LabelAnchor(id: 'b', preferredTop: 110, height: 20),
        ],
        gap: 4,
      );
      expect(tops['a'], 100);
      expect(tops['b'], 124);
    });

    test('three near-simultaneous labels read one-by-one', () {
      final tops = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          LabelAnchor(id: 'b', preferredTop: 102, height: 20),
          LabelAnchor(id: 'c', preferredTop: 104, height: 20),
        ],
        gap: 4,
      );
      expect(tops['a'], 100);
      expect(tops['b'], 124);
      expect(tops['c'], 148);
    });

    test('a label is never pushed ABOVE its own icon', () {
      final tops = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          // Far below — must NOT be pulled up to 124.
          LabelAnchor(id: 'b', preferredTop: 500, height: 20),
        ],
        gap: 4,
      );
      expect(tops['b'], 500);
    });

    test('input order does not matter — placement is chronological', () {
      final ordered = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
          LabelAnchor(id: 'b', preferredTop: 100, height: 20),
        ],
        gap: 4,
      );
      final reversed = computeLabelTops(
        anchors: const [
          LabelAnchor(id: 'b', preferredTop: 100, height: 20),
          LabelAnchor(id: 'a', preferredTop: 100, height: 20),
        ],
        gap: 4,
      );
      expect(reversed.values.toSet(), ordered.values.toSet());
    });
  });
}
