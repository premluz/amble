import 'package:amble/core/tokens/depth_motion_spec.dart';
import 'package:amble/core/widgets/app_depth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _spec = DepthMotionSpec.standard;
const _rowHeight = 50.0;
const _frame = Duration(milliseconds: 16);

Widget _host({
  bool present = true,
  bool animateIn = false,
  Duration delay = Duration.zero,
  VoidCallback? onExited,
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          AppDepthPresence(
            present: present,
            animateIn: animateIn,
            delay: delay,
            onExited: onExited,
            child: const SizedBox(
              key: ValueKey('row'),
              height: _rowHeight,
              width: 200,
              child: Row(
                children: [
                  AppDepthShape(
                    child: SizedBox(
                      key: ValueKey('pill'),
                      width: 24,
                      height: 24,
                    ),
                  ),
                  AppDepthFade(child: Text('Title')),
                ],
              ),
            ),
          ),
          const SizedBox(key: ValueKey('below'), height: 10, width: 100),
        ],
      ),
    ),
  );
}

double _belowTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('below'))).dy;

double _pillScale(WidgetTester tester) => tester
    .widget<Transform>(
      find.ancestor(
        of: find.byKey(const ValueKey('pill')),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .storage[0];

double _pillOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('pill')),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

double _textOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(
        of: find.text('Title'),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

Future<List<double>> _record(
  WidgetTester tester,
  Duration total,
  double Function(WidgetTester) read,
) async {
  final out = <double>[];
  for (var t = Duration.zero; t < total; t += _frame) {
    await tester.pump(_frame);
    out.add(read(tester));
  }
  return out;
}

void main() {
  testWidgets('an existing object is simply there — no entrance', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_belowTop(tester), _rowHeight);
    expect(_pillScale(tester), 1);
    expect(_textOpacity(tester), 1);
  });

  testWidgets('arriving: the row opens its room (neighbours move down) but '
      'never scales, blurs or moves sideways as a whole', (tester) async {
    await tester.pumpWidget(_host(animateIn: true));
    final rowLeft = tester.getTopLeft(find.byKey(const ValueKey('row'))).dx;
    await tester.pump(_spec.enterDuration * .3);
    expect(_belowTop(tester), greaterThan(0));
    expect(_belowTop(tester), lessThan(_rowHeight));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('row'))).dx,
      rowLeft,
      reason: 'no sideways movement',
    );
    expect(find.byType(ImageFiltered), findsNothing, reason: 'no blur');
    await tester.pumpAndSettle();
    expect(_belowTop(tester), _rowHeight);
  });

  testWidgets('the pill springs up from small and transparent: larger, then '
      'smaller, then exactly its real size', (tester) async {
    await tester.pumpWidget(_host(animateIn: true));
    expect(_pillScale(tester), closeTo(_spec.shapeFromScale, .01));
    expect(_pillOpacity(tester), 0);

    final scales = await _record(tester, _spec.enterDuration, _pillScale);
    final peakAt = scales.indexWhere(
      (s) => s == scales.reduce((a, b) => a > b ? a : b),
    );
    expect(scales[peakAt], greaterThan(1.03), reason: 'larger');
    final afterPeak = scales.sublist(peakAt);
    expect(
      afterPeak.reduce((a, b) => a < b ? a : b),
      lessThan(1),
      reason: 'then smaller',
    );
    await tester.pumpAndSettle();
    expect(_pillScale(tester), 1, reason: 'then actual');
    expect(_pillOpacity(tester), 1);
  });

  testWidgets('nothing cuts off the springing pill: while the room opens only '
      'the bottom edge is clipped, and once open nothing is', (tester) async {
    ClipRect clip() => tester.widget<ClipRect>(
      find.descendant(
        of: find.byType(AppDepthPresence),
        matching: find.byType(ClipRect),
      ),
    );
    await tester.pumpWidget(_host(animateIn: true));
    await tester.pump(_spec.enterDuration * (_spec.sizeEnd * .5));
    final opening = clip().clipper!.getClip(const Size(200, _rowHeight));
    expect(opening.left, lessThan(0), reason: 'left side open');
    expect(opening.top, lessThan(0), reason: 'top open');
    expect(opening.bottom, _rowHeight, reason: 'only the growing edge');

    // Past the room-opening phase but while the pill is still springing.
    await tester.pump(_spec.enterDuration * (_spec.sizeEnd * .6));
    var sawOvershootUnclipped = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(_frame);
      if (_pillScale(tester) > 1 && clip().clipBehavior == Clip.none) {
        sawOvershootUnclipped = true;
      }
    }
    expect(sawOvershootUnclipped, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('the text only fades in — it never scales', (tester) async {
    await tester.pumpWidget(_host(animateIn: true));
    expect(_textOpacity(tester), 0);
    expect(
      find.ancestor(of: find.text('Title'), matching: find.byType(Transform)),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(_textOpacity(tester), 1);
  });

  testWidgets('a delay staggers the arrival', (tester) async {
    await tester.pumpWidget(
      _host(animateIn: true, delay: const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(_belowTop(tester), 0, reason: 'still waiting its turn');
    await tester.pumpAndSettle();
    expect(_belowTop(tester), _rowHeight);
  });

  testWidgets('removal: the pill shrinks and fades without bouncing, the text '
      'fades, the room closes, and only THEN the caller deletes', (
    tester,
  ) async {
    var exited = 0;
    await tester.pumpWidget(_host(onExited: () => exited++));
    await tester.pumpWidget(_host(present: false, onExited: () => exited++));
    final scales = await _record(tester, _spec.exitDuration * .5, _pillScale);
    expect(scales.every((s) => s <= 1), isTrue, reason: 'no bounce leaving');
    expect(exited, 0, reason: 'not before it has gone');
    await tester.pumpAndSettle();
    expect(exited, 1);
    expect(_belowTop(tester), 0, reason: 'its room is given back');
  });

  testWidgets('reduced motion: arrives and leaves instantly', (tester) async {
    var exited = 0;
    await tester.pumpWidget(_host(animateIn: true, reduceMotion: true));
    expect(_belowTop(tester), _rowHeight);
    expect(_pillScale(tester), 1);
    await tester.pumpWidget(
      _host(present: false, reduceMotion: true, onExited: () => exited++),
    );
    expect(exited, 1);
  });

  testWidgets('outside a presence, shape and fade markers are inert', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppDepthShape(child: AppDepthFade(child: Text('Plain'))),
      ),
    );
    expect(find.byType(Transform), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);
  });
}
