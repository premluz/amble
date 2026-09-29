import 'package:amble/core/tokens/liquid_morph_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_pane_morph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = Rect.fromLTWH(300, 500, 48, 48);
const _target = Rect.fromLTWH(20, 500, 360, 48);
const _frame = Duration(milliseconds: 16);
final _duration = LiquidMorphSpec.dockPane.widthDuration * 1.4;

Future<AnimationController> _pump(WidgetTester tester) async {
  final controller = AnimationController(
    vsync: const TestVSync(),
    duration: _duration,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.dark]),
      home: Scaffold(
        body: AppPaneMorph(
          theme: AmbleTheme.dark,
          animation: controller,
          origin: _origin,
          target: _target,
          from: const Icon(Icons.mic_none_rounded),
          child: Center(
            child: TextButton(onPressed: () {}, child: const Text('toolbar')),
          ),
        ),
      ),
    ),
  );
  return controller;
}

Rect _pane(WidgetTester tester) => tester.getRect(
  find
      .ancestor(of: find.byType(AppDockSurface), matching: find.byType(Opacity))
      .first,
);

void main() {
  testWidgets('starts as the origin pane showing the origin content', (
    tester,
  ) async {
    await _pump(tester);
    expect(_pane(tester), _origin);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('forward: stretches PAST the target width, then lands exactly '
      'on it, with the new content in and the old one gone', (tester) async {
    final controller = await _pump(tester);
    controller.forward();
    var widest = 0.0;
    for (var t = Duration.zero; t < _duration; t += _frame) {
      await tester.pump(_frame);
      final width = _pane(tester).width;
      if (width > widest) widest = width;
    }
    await tester.pumpAndSettle();
    expect(widest, greaterThan(_target.width), reason: 'springy overshoot');
    expect(_pane(tester), _target);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.text('toolbar'), findsOneWidget);
  });

  testWidgets('the target content takes taps only once the morph is done', (
    tester,
  ) async {
    final controller = await _pump(tester);
    controller.forward();
    await tester.pump(_duration * .5);
    IgnorePointer gate() => tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.text('toolbar'),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(gate().ignoring, isTrue);
    await tester.pumpAndSettle();
    expect(gate().ignoring, isFalse);
  });

  testWidgets('back: returns into the origin without ever growing past the '
      'target', (tester) async {
    final controller = await _pump(tester);
    controller.value = 1;
    await tester.pump();
    controller.reverse();
    for (var t = Duration.zero; t < _duration; t += _frame) {
      await tester.pump(_frame);
      expect(_pane(tester).width, lessThanOrEqualTo(_target.width));
    }
    await tester.pumpAndSettle();
    expect(_pane(tester), _origin);
  });

  testWidgets('back: decisive — it speeds up into the origin and is home '
      'early, well before the animation ends', (tester) async {
    final controller = await _pump(tester);
    controller.value = 1;
    await tester.pump();
    controller.reverse();
    final lefts = <double>[];
    while (controller.value > AppPaneMorph.returnEnd) {
      await tester.pump(_frame);
      lefts.add(_pane(tester).left);
    }
    expect(_pane(tester).left, closeTo(_origin.left, .5), reason: 'home');
    final early = lefts[2] - lefts[0];
    final late = lefts[lefts.length - 1] - lefts[lefts.length - 3];
    expect(late, greaterThan(early), reason: 'speeding up, not drifting in');
    await tester.pumpAndSettle();
  });

  testWidgets('arriving, the whole pane springs larger, then smaller, then '
      'exactly its size', (tester) async {
    final controller = await _pump(tester);
    controller.forward();
    final heights = <double>[];
    for (var t = Duration.zero; t < _duration; t += _frame) {
      await tester.pump(_frame);
      heights.add(_pane(tester).height);
    }
    final peak = heights.reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(_target.height * 1.02), reason: 'larger');
    expect(
      heights.sublist(heights.indexOf(peak)).reduce((a, b) => a < b ? a : b),
      lessThan(_target.height),
      reason: 'then smaller',
    );
    await tester.pumpAndSettle();
    expect(_pane(tester), _target, reason: 'then actual');
  });

  testWidgets('with its real forward duration, the stretch settles early '
      'instead of crawling across the whole transition', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 700),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.dark]),
        home: Scaffold(
          body: AppPaneMorph(
            theme: AmbleTheme.dark,
            animation: controller,
            forwardSeconds: .7,
            origin: _origin,
            target: _target,
            from: const Icon(Icons.mic_none_rounded),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    controller.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      (_pane(tester).left - _target.left).abs(),
      lessThan(_target.width * .05),
      reason: 'stretched out by ~450ms of a 700ms entrance',
    );
    await tester.pumpAndSettle();
  });
}
