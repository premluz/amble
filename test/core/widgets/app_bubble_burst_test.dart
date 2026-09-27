import 'package:amble/core/tokens/bubble_burst_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bubble_burst.dart';
import 'package:amble/core/widgets/bubble_burst_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeded micro bubbles rise, stay tiny, and scale with the source', () {
    for (final width in [20.0, 32.0]) {
      final particles = bubbleParticlesAt(
        seconds: .3,
        sourceWidth: width,
      ).toList();
      expect(particles, isNotEmpty);
      expect(particles.length, lessThanOrEqualTo(6));
      expect(particles.every((p) => p.offset.dy < 0), isTrue);
      expect(particles.every((p) => p.radius * 2 < width / 5), isTrue);
      final repeat = bubbleParticlesAt(
        seconds: .3,
        sourceWidth: width,
      ).toList();
      expect(repeat.map((p) => p.offset), particles.map((p) => p.offset));
      final larger = bubbleParticlesAt(
        seconds: .3,
        sourceWidth: width * 2,
      ).toList();
      expect(larger.first.offset, particles.first.offset * 2);
      expect(larger.first.radius, particles.first.radius * 2);
      expect(
        bubbleParticlesAt(
          seconds: const BubbleBurstSpec().seconds,
          sourceWidth: width,
        ),
        isEmpty,
      );
    }
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'overlay survives source removal, cleans up; reduced=$reduced',
      (tester) async {
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        var backgroundTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AmbleTheme.light]),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => backgroundTaps++,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: visible,
                        builder: (context, show, _) => !show
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.all(80),
                                child: Builder(
                                  builder: (source) => GestureDetector(
                                    key: const Key('source'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      AppBubbleBurst.show(
                                        context: source,
                                        origin: const Offset(10, 0),
                                        sourceWidth: 20,
                                      );
                                      visible.value = false;
                                    },
                                    child: const SizedBox(
                                      width: 20,
                                      height: 50,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('source')));
        await tester.pump();
        expect(find.byKey(const Key('source')), findsNothing);
        expect(
          find.byType(BubbleBurstEffect),
          reduced ? findsNothing : findsOneWidget,
        );
        if (!reduced) {
          final effect = tester.widget<BubbleBurstEffect>(
            find.byType(BubbleBurstEffect),
          );
          expect(effect.origin, const Offset(90, 80));
          expect(effect.color, AmbleTheme.light.colorAccent);
        }
        await tester.tapAt(const Offset(90, 60));
        expect(backgroundTaps, 1);
        await tester.pumpAndSettle();
        expect(find.byType(BubbleBurstEffect), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
