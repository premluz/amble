import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/motion_primitives.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_staggered_fill.dart';

/// Patterns' completed days colour in one after another, quickly — the one
/// stagger kept when page slides are off (requested directly).
const _rest = Color(0xFF000000);
const _done = Color(0xFFFFFFFF);

Widget _cells({required int arrival, bool reduceMotion = false}) =>
    MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.light]),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: AppViewArrival(
          arrival: arrival,
          child: Row(
            children: [
              for (final (i, order) in [0.0, 1.0, .5].indexed)
                AppStaggeredFill(
                  key: ValueKey(i),
                  rest: _rest,
                  color: i == 2 ? _rest : _done,
                  order: order,
                  builder: (context, fill) => ColoredBox(
                    key: ValueKey('cell-$i'),
                    color: fill,
                    child: const SizedBox.square(dimension: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

Color _fill(WidgetTester tester, int i) =>
    tester.widget<ColoredBox>(find.byKey(ValueKey('cell-$i'))).color;

void main() {
  const fast = Duration(milliseconds: MotionPrimitives.durationFastMs);
  const spread = Duration(milliseconds: MotionPrimitives.durationFillStaggerMs);

  testWidgets('done days colour in by order; others stay as they are', (
    tester,
  ) async {
    await tester.pumpWidget(_cells(arrival: 0));
    expect(_fill(tester, 0), _rest);
    expect(_fill(tester, 1), _rest);

    await tester.pump(fast);
    expect(_fill(tester, 0), _done, reason: 'first in order: done');
    expect(_fill(tester, 1), _rest, reason: 'last in order: not started');

    await tester.pump(spread);
    expect(_fill(tester, 1), _done);
    expect(_fill(tester, 2), _rest, reason: 'not done: never animates');
  });

  testWidgets('it plays again when its page arrives again', (tester) async {
    await tester.pumpWidget(_cells(arrival: 0));
    await tester.pumpAndSettle();
    expect(_fill(tester, 0), _done);

    await tester.pumpWidget(_cells(arrival: -1));
    await tester.pumpWidget(_cells(arrival: 1));
    expect(_fill(tester, 0), _rest);
    await tester.pumpAndSettle();
    expect(_fill(tester, 0), _done);
  });

  testWidgets('reduced motion shows the colour at once', (tester) async {
    await tester.pumpWidget(_cells(arrival: 0, reduceMotion: true));
    await tester.pump();
    expect(_fill(tester, 1), _done);
  });
}
