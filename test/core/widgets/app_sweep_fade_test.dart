import 'package:amble/core/widgets/app_sweep_fade.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Painted opacity of the item keyed [key].
double _opacity(WidgetTester tester, String key) => tester
    .renderObject<RenderSweepFade>(
      find.ancestor(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(AppSweepFade),
      ),
    )
    .debugOpacity;

Future<void> _pump(WidgetTester tester, Animation<double> sweep) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final key in ['top', 'middle', 'bottom'])
              AppSweepFade(
                sweep: sweep,
                child: SizedBox(key: ValueKey(key), height: 40, width: 40),
              ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('at rest everything is fully visible', (tester) async {
    await _pump(tester, kAlwaysDismissedAnimation);
    for (final key in ['top', 'middle', 'bottom']) {
      expect(_opacity(tester, key), 1);
    }
  });

  testWidgets('sweeping up: the bottom item fades first, the top one last', (
    tester,
  ) async {
    final sweep = AnimationController(vsync: const TestVSync());
    addTearDown(sweep.dispose);
    await _pump(tester, sweep);
    sweep.value = .4;
    await tester.pump();
    final top = _opacity(tester, 'top');
    final middle = _opacity(tester, 'middle');
    final bottom = _opacity(tester, 'bottom');
    expect(bottom, lessThan(middle));
    expect(middle, lessThan(top));
  });

  testWidgets('fully swept: everything is gone', (tester) async {
    await _pump(tester, kAlwaysCompleteAnimation);
    for (final key in ['top', 'middle', 'bottom']) {
      expect(_opacity(tester, key), 0);
    }
  });

  testWidgets('at rest it adds no layer at all — idle rows cost nothing', (
    tester,
  ) async {
    await _pump(tester, kAlwaysDismissedAnimation);
    final box = tester.renderObject<RenderSweepFade>(
      find.ancestor(
        of: find.byKey(const ValueKey('top')),
        matching: find.byType(AppSweepFade),
      ),
    );
    expect(box.debugLayer, isNull);
  });
}
