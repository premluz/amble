import 'package:amble/core/tokens/liquid_morph_spec.dart';
import 'package:amble/core/widgets/app_liquid_morph.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _spec = LiquidMorphSpec.popover;
const _size = Size(200, 120);
const _radius = 24.0;
final double _droplet = switch (_spec.dropletDiameter) {
  final double d => d,
  null => _size.shortestSide,
};

Widget _host({required Offset origin, bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: _size,
          child: AppLiquidMorph(
            origin: origin,
            borderRadius: _radius,
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    ),
  );
}

RRect _clip(WidgetTester tester) => tester
    .widget<ClipRRect>(
      find.descendant(
        of: find.byType(AppLiquidMorph),
        matching: find.byType(ClipRRect),
      ),
    )
    .clipper!
    .getClip(_size);

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(AppLiquidMorph),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('starts as a droplet at the origin', (tester) async {
    await tester.pumpWidget(_host(origin: const Offset(100, 0)));
    final clip = _clip(tester);
    expect(clip.width, closeTo(_droplet, .01));
    expect(clip.height, closeTo(_droplet, .01));
    expect(clip.center, const Offset(100, 0));
    expect(clip.tlRadiusX, closeTo(_droplet / 2, .01));
    expect(_opacity(tester), 0);
  });

  testWidgets('widens before it stretches', (tester) async {
    await tester.pumpWidget(_host(origin: const Offset(100, 0)));
    await tester.pump(const Duration(milliseconds: 80));
    final clip = _clip(tester);
    final widthShare = (clip.width - _droplet) / (_size.width - _droplet);
    final heightShare = (clip.height - _droplet) / (_size.height - _droplet);
    expect(widthShare, greaterThan(heightShare));
  });

  testWidgets('settles exactly into the full rounded shape', (tester) async {
    await tester.pumpWidget(_host(origin: const Offset(100, 0)));
    await tester.pumpAndSettle();
    final clip = _clip(tester);
    expect(clip.outerRect, Offset.zero & _size);
    expect(clip.tlRadiusX, _radius);
    expect(_opacity(tester), 1);
    final transform = tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AppLiquidMorph),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    expect(transform, Matrix4.identity());
  });

  testWidgets('popover pops a touch oversized, then settles back', (
    tester,
  ) async {
    await tester.pumpWidget(_host(origin: const Offset(100, 0)));
    double scaleY() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AppLiquidMorph),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[5];
    var peak = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      peak = scaleY() > peak ? scaleY() : peak;
    }
    expect(peak, greaterThan(1.03), reason: 'visibly oversized');
    expect(peak, lessThan(1.08), reason: 'slight, not cartoonish');
    await tester.pumpAndSettle();
    expect(scaleY(), 1);
  });

  testWidgets('the overshoot never cuts back into the rim: once fully '
      'revealed, the clip stays out and then switches off', (tester) async {
    // Origin ON the top edge, as a menu opening below the finger: the case
    // where the height overshoot used to pull the clip inside the rim and
    // hide the glass's top highlight mid-entrance.
    await tester.pumpWidget(_host(origin: const Offset(100, 0)));
    ClipRRect clipWidget() => tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(AppLiquidMorph),
        matching: find.byType(ClipRRect),
      ),
    );
    final full = Offset.zero & _size;
    var revealed = false;
    var clipOffWhileMoving = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      final clip = clipWidget();
      final shape = clip.clipper!.getClip(_size).outerRect;
      final covers =
          shape.left <= full.left &&
          shape.top <= full.top &&
          shape.right >= full.right &&
          shape.bottom >= full.bottom;
      if (revealed) {
        expect(covers, isTrue, reason: 'frame $i cut back inside the rim');
      }
      revealed = revealed || covers;
      if (clip.clipBehavior == Clip.none && tester.binding.hasScheduledFrame) {
        clipOffWhileMoving = true;
      }
    }
    expect(revealed, isTrue);
    expect(
      clipOffWhileMoving,
      isTrue,
      reason: 'the clip drops as soon as the shape forms, not at rest',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('an origin outside the shape grows from the nearest edge', (
    tester,
  ) async {
    await tester.pumpWidget(_host(origin: const Offset(100, -40)));
    expect(_clip(tester).center, const Offset(100, 0));
  });

  testWidgets('reduced motion: fully formed on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(origin: const Offset(100, 0), reduceMotion: true),
    );
    expect(_clip(tester).outerRect, Offset.zero & _size);
    expect(_opacity(tester), 1);
  });
}
