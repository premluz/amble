import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/water_ripple_spec.dart';
import 'package:amble/core/widgets/app_water_ripple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _spec = WaterRippleSpec();

void main() {
  group('waterRingsAt', () {
    test('nothing before the first ring or after the last', () {
      expect(waterRingsAt(seconds: 0, spec: _spec), isEmpty);
      expect(waterRingsAt(seconds: _spec.seconds, spec: _spec), isEmpty);
    });

    test('rings spread outward and fade, never past spread or peak', () {
      final samples = [
        for (var s = .01; s < _spec.seconds; s += .01)
          ...waterRingsAt(seconds: s, spec: _spec),
      ];
      expect(samples, isNotEmpty);
      for (final ring in samples) {
        expect(ring.distance, inInclusiveRange(0, _spec.spread));
        expect(ring.opacity, inInclusiveRange(0, _spec.peakOpacity));
      }
      final early = waterRingsAt(seconds: .1, spec: _spec).first;
      final late = waterRingsAt(seconds: .6, spec: _spec).first;
      expect(late.distance, greaterThan(early.distance));
      expect(late.opacity, lessThan(early.opacity));
    });

    test('a later ring travels less far than the first', () {
      // Each ring sampled at 99% of its own life; ring 0 has ended by the
      // time ring 1 gets there, so each sample holds the ring in question.
      final nearEnd = _spec.ringSeconds * .99;
      final first = waterRingsAt(seconds: nearEnd, spec: _spec).first;
      final second = waterRingsAt(
        seconds: _spec.ringDelaySeconds + nearEnd,
        spec: _spec,
      ).single;
      expect(second.distance, lessThan(first.distance));
    });
  });

  group('AppWaterRipple.show', () {
    Widget host({bool reduceMotion = false}) => MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => GestureDetector(
              key: const Key('source'),
              behavior: HitTestBehavior.opaque,
              onTap: () => AppWaterRipple.show(
                context: context,
                rect: const Rect.fromLTWH(0, 0, 24, 80),
                radius: 12,
              ),
              child: const SizedBox(width: 24, height: 80),
            ),
          ),
        ),
      ),
    );

    testWidgets('paints on the overlay, then removes itself', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('source')));
      await tester.pump();
      expect(find.byType(WaterRippleEffect), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(WaterRippleEffect), findsNothing);
    });

    testWidgets('reduced motion: nothing is inserted', (tester) async {
      await tester.pumpWidget(host(reduceMotion: true));
      await tester.tap(find.byKey(const Key('source')));
      await tester.pump();
      expect(find.byType(WaterRippleEffect), findsNothing);
    });
  });
}
