import 'package:amble/core/tokens/depth_motion_spec.dart';
import 'package:amble/core/widgets/app_spring_presence.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _duration = Duration(milliseconds: 250);
const _frame = Duration(milliseconds: 16);

Widget _host(bool visible, {bool still = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: still),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: AppSpringPresence(
      visible: visible,
      duration: _duration,
      child: const SizedBox(key: ValueKey('item'), width: 40, height: 40),
    ),
  ),
);

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;
double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

Future<List<double>> _scales(WidgetTester tester) async {
  final out = <double>[];
  for (var i = 0; i < 60; i++) {
    await tester.pump(_frame);
    out.add(_scale(tester));
  }
  return out;
}

void main() {
  testWidgets('already visible: simply there', (tester) async {
    await tester.pumpWidget(_host(true));
    expect(_scale(tester), 1);
    expect(_opacity(tester), 1);
  });

  testWidgets('showing: fades in while springing larger, then smaller, then '
      'exactly its real size', (tester) async {
    await tester.pumpWidget(_host(false));
    expect(_scale(tester), DepthMotionSpec.standard.shapeFromScale);
    expect(_opacity(tester), 0);
    await tester.pumpWidget(_host(true));
    final scales = await _scales(tester);
    final peak = scales.reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.02), reason: 'larger');
    final afterPeak = scales.sublist(scales.indexOf(peak));
    expect(
      afterPeak.reduce((a, b) => a < b ? a : b),
      lessThan(1),
      reason: 'then smaller',
    );
    await tester.pumpAndSettle();
    expect(_scale(tester), 1, reason: 'then actual');
    expect(_opacity(tester), 1);
  });

  testWidgets('hiding: shrinks and fades without bouncing', (tester) async {
    await tester.pumpWidget(_host(true));
    await tester.pumpWidget(_host(false));
    final scales = await _scales(tester);
    expect(scales.every((s) => s <= 1), isTrue);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
  });

  testWidgets('reduced motion: instant both ways', (tester) async {
    await tester.pumpWidget(_host(false, still: true));
    await tester.pumpWidget(_host(true, still: true));
    expect(_scale(tester), 1);
    expect(_opacity(tester), 1);
  });

  testWidgets('submerging (swell): it swells larger first, then shrinks '
      'away and fades out', (tester) async {
    Widget host(bool visible) => Directionality(
      textDirection: TextDirection.ltr,
      child: AppSpringPresence(
        visible: visible,
        duration: _duration,
        swell: .15,
        child: const SizedBox(width: 40, height: 40),
      ),
    );
    await tester.pumpWidget(host(true));
    await tester.pumpWidget(host(false));
    final scales = await _scales(tester);
    final peak = scales.reduce((a, b) => a > b ? a : b);
    expect(peak, closeTo(1.15, .01), reason: 'larger');
    expect(scales.indexOf(peak), lessThan(scales.length ~/ 2));
    expect(scales.last, DepthMotionSpec.standard.shapeFromScale);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
  });
}
