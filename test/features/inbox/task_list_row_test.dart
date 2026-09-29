import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/features/inbox/task_list_row.dart';
import 'package:amble/features/inbox/voice_capture_screen_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _theme = AmbleTheme.dark;

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [_theme]),
  home: Scaffold(body: child),
);

Color _pillColor(WidgetTester tester, Finder row) {
  final pill = tester.widget<Container>(
    find.descendant(of: row, matching: find.byType(Container)).first,
  );
  final decoration = pill.decoration;
  if (decoration is! BoxDecoration) fail('pill has no box decoration');
  final color = decoration.color;
  if (color == null) fail('pill has no fill');
  return color;
}

void main() {
  testWidgets('voice mode draws each line as the same card as an Inbox '
      'task: same pill size, and the unassigned tone for a line with no '
      'label yet', (tester) async {
    await tester.pumpWidget(
      _host(
        VoiceCaptureSegmentList(
          theme: _theme,
          segments: const ['Call John'],
          partialText: 'Book the',
        ),
      ),
    );
    final rows = find.byType(TaskListRow);
    expect(rows, findsNWidgets(2));
    for (final row in [rows.first, rows.last]) {
      expect(_pillColor(tester, row), TaskStateTokens.unlabeledFill(_theme));
    }
    final pill = find
        .descendant(of: rows.first, matching: find.byType(Container))
        .first;
    expect(tester.getSize(pill), Size.square(_theme.sizeTaskBadge));
  });

  testWidgets('only the line still being spoken shows the edge trace, and '
      'it fills over the silence window', (tester) async {
    await tester.pumpWidget(
      _host(
        VoiceCaptureSegmentList(
          theme: _theme,
          segments: const ['Call John'],
          partialText: 'Book the',
        ),
      ),
    );
    final rows = find.byType(TaskListRow);
    expect(tester.widget<TaskListRow>(rows.first).pendingProgress, isNull);
    final early = tester.widget<TaskListRow>(rows.last).pendingProgress!;
    await tester.pump(const Duration(milliseconds: 800));
    final later = tester.widget<TaskListRow>(rows.last).pendingProgress!;
    expect(later, greaterThan(early));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the trace is a hairline just OUTSIDE the pill: nothing is '
      'painted over the pill itself', (tester) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: TaskListRow(
            theme: _theme,
            title: 'Book the flight',
            pillColor: TaskStateTokens.unlabeledFill(_theme),
            pendingProgress: 1,
          ),
        ),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find
          .ancestor(
            of: find
                .descendant(
                  of: find.byType(TaskListRow),
                  matching: find.byType(Container),
                )
                .first,
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final badge = _theme.sizeTaskBadge;
    const margin = 6;
    final side = (badge + margin * 2).round();
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(margin.toDouble(), margin.toDouble());
      paint.foregroundPainter!.paint(canvas, Size.square(badge));
      final image = await recorder.endRecording().toImage(side, side);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data;
    });
    if (bytes == null) throw StateError('Edge trace capture failed');
    int alpha(ByteData b, int x, int y) => b.getUint8((y * side + x) * 4 + 3);
    final centre = side ~/ 2;
    expect(alpha(bytes, centre, centre), 0, reason: 'pill untouched');
    expect(
      alpha(bytes, centre, margin + 1),
      0,
      reason: 'not over the pill\'s own edge either',
    );
    // Just above the pill's top edge: the trace.
    final above = [for (var y = 0; y < margin; y++) alpha(bytes, centre, y)];
    expect(above.any((a) => a > 0), isTrue, reason: 'traced outside');
  });
}
