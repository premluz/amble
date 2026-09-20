import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/current_time_indicator.dart';

/// Covers the corrected layout requested directly: "current time the red
/// dot should not be close to screen edge, instead... 09:00 / 09:31
/// o-------- / 10:00... currently is not aligned with other hours and dot
/// should be after time not in front." The time text must start at the
/// SAME x as every other hour tick, with the dot AFTER it (not before).
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(WidgetTester tester, {required DateTime now}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: [
                CurrentTimeIndicator(
                  rangeStart: DateTime(now.year, now.month, now.day),
                  rangeEnd: DateTime(now.year, now.month, now.day, 23, 59),
                  leftInset: theme.spacingSm,
                  pixelsPerMinute: 1.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'the time pill starts at the SAME x as leftInset — the shared hour-'
    'gutter x, not flush with the screen edge',
    (tester) async {
      await tester.runAsync(() async {
        await pump(tester, now: DateTime.now());
      });
      await tester.pump();

      final row = tester.getTopLeft(find.byType(Row).first);
      expect(row.dx, theme.spacingSm);
    },
  );

  testWidgets('the dot renders AFTER the time text, not before it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pump(tester, now: DateTime.now());
    });
    await tester.pump();

    final textLeft = tester.getTopLeft(find.byType(Text)).dx;
    final dotFinder = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    final dotLeft = tester.getTopLeft(dotFinder).dx;

    expect(
      dotLeft,
      greaterThan(textLeft),
      reason: 'requested directly: "dot should be after time not in front"',
    );
  });

  testWidgets('the line still extends to the right, filling the row', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pump(tester, now: DateTime.now());
    });
    await tester.pump();

    expect(find.byType(Expanded), findsOneWidget);
  });
}
