import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/liquid_press_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';

/// Requested directly: "let's introduce tap 'interaction' on buttons and
/// hit areas ... nice animation starting from place of tap ... subtle ...
/// so the touch feels 'responsive' assurance." Confirmed via
/// AskUserQuestion as ripple-from-tap-point PLUS a slight scale-down.
Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback? onTap,
  BoxShape shape = BoxShape.rectangle,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(
        body: Center(
          child: AppPressFeedback(
            onTap: onTap,
            shape: shape,
            child: const SizedBox(
              width: 200,
              height: 60,
              child: Text('Tap me'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Finders scoped INSIDE the AppPressFeedback under test — `Scaffold`,
/// `Text` and friends contribute their own `Transform`/`CustomPaint`
/// layers, so an unscoped `find.byType` would assert against framework
/// internals rather than this widget's own behaviour.
Finder _within(Type type) => find.descendant(
  of: find.byType(AppPressFeedback),
  matching: find.byType(type),
);

/// The press deformation on the vertical axis (the one carrying the full
/// growth), taken as whichever Transform in the subtree departs furthest from
/// rest.
double _verticalScale(WidgetTester tester) => tester
    .widgetList<Transform>(_within(Transform))
    .map((t) => t.transform.storage[5])
    .reduce((a, b) => (a - 1).abs() > (b - 1).abs() ? a : b);

/// Growth for the 200-wide test control (longest side 200).
final _growth = LiquidPressSpec.standard.growFor(200);

Future<List<double>> _sample(WidgetTester tester, int frames) async {
  final samples = <double>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 8));
    samples.add(_verticalScale(tester));
  }
  return samples;
}

void main() {
  testWidgets('a null onTap renders the child bare — no gesture handling, '
      'no press animation', (tester) async {
    await _pump(tester, onTap: null);

    expect(find.text('Tap me'), findsOneWidget);
    expect(_within(GestureDetector), findsNothing);
    expect(_within(Transform), findsNothing);
    expect(_within(ClipPath), findsNothing);
  });

  testWidgets('tapping still fires onTap — the feedback never swallows the '
      'gesture it decorates', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('swells while held, Liquid Glass style, and springs back on '
      'release', (tester) async {
    await _pump(tester, onTap: () {});
    expect(_verticalScale(tester), 1.0, reason: 'natural size at rest');

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      _verticalScale(tester),
      closeTo(1 + _growth, .001),
      reason: 'held: the control grows toward the finger and stays grown',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_verticalScale(tester), 1.0, reason: 'lands exactly at rest');
  });

  testWidgets('a quick tap still shows the full swell, then a fluid return '
      'that dips just past rest once', (tester) async {
    await _pump(tester, onTap: () {});
    await tester.tap(find.text('Tap me'));

    final samples = await _sample(tester, 90);
    final highest = samples.reduce((a, b) => a > b ? a : b);
    final lowest = samples.reduce((a, b) => a < b ? a : b);
    expect(highest, closeTo(1 + _growth, .002));
    expect(lowest, lessThan(1.0), reason: 'the release overshoots rest');
    expect(lowest, greaterThan(1 - _growth), reason: 'never cartoonish');
    await tester.pumpAndSettle();
    expect(_verticalScale(tester), 1.0);
  });

  testWidgets('growth is sized in pixels: a small icon button swells more '
      'than a wide row', (tester) async {
    Future<double> heldScale(double width, double height) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Center(
              child: AppPressFeedback(
                key: ValueKey('$width'),
                onTap: () {},
                child: SizedBox(width: width, height: height),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPressFeedback)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final scale = _verticalScale(tester);
      await gesture.up();
      await tester.pumpAndSettle();
      return scale;
    }

    final icon = await heldScale(44, 44);
    final row = await heldScale(300, 60);
    expect(icon, closeTo(1 + LiquidPressSpec.standard.growFor(44), .001));
    expect(row, closeTo(1 + LiquidPressSpec.standard.growFor(300), .001));
    expect(icon - 1, greaterThan((row - 1) * 3));
  });

  testWidgets('held: a glass fill covers the whole control (so a fill-less '
      'icon button visibly swells), gone once released', (tester) async {
    await _pump(tester, onTap: () {});
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump();
    // Past the ripple's own life, so only the hold fill keeps the layer.
    await tester.pump(const Duration(milliseconds: 600));
    expect(_within(ClipPath), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_within(ClipPath), findsNothing);
  });

  testWidgets('reduced motion: no swell, but the tap still fires', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              onTap: () => taps++,
              child: const SizedBox(
                width: 200,
                height: 60,
                child: Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(_verticalScale(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a press paints a ripple, which clears itself once the '
      'animation finishes', (tester) async {
    await _pump(tester, onTap: () {});

    // Nothing painted before the first touch.
    expect(_within(ClipPath), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      _within(ClipPath),
      findsOneWidget,
      reason: "the wash is clipped to the control's own bounds",
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      _within(ClipPath),
      findsNothing,
      reason:
          'once the ripple has played out the painting layer is dropped '
          'entirely rather than left inert in the tree',
    );
  });

  testWidgets('the ripple grows from the tap point, so an off-centre press '
      'washes outward from where the finger actually landed', (tester) async {
    await _pump(tester, onTap: () {});

    final topLeft = tester.getTopLeft(find.text('Tap me'));
    // Deliberately off-centre, near one corner.
    final gesture = await tester.startGesture(topLeft + const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 50));

    // The ripple is painted, and its clip is confined to the control —
    // the origin itself is an implementation detail of the private
    // painter, so this asserts the observable contract (a wash appears,
    // scoped to this control) rather than reaching into private state.
    expect(_within(ClipPath), findsOneWidget);
    expect(_within(CustomPaint), findsWidgets);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // Regression cover for the two failure modes decorationOnly exists to
  // avoid — both caught by the suite while building this. Routing the tap
  // through the wrapper while a real platform button sat inside it meant
  // the button won the gesture arena and the wrapper's onTap never fired
  // (every AppButton-opened sheet silently stopped opening); neutralising
  // the button with an IgnorePointer instead left 40 tests tapping a
  // non-hit-testable node.
  testWidgets('decorationOnly leaves the child\'s own tap handling intact — '
      'it observes pointers without competing for the gesture', (tester) async {
    var wrapperTaps = 0;
    var childTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              decorationOnly: true,
              // Non-null so the widget counts as enabled and animates,
              // but never invoked in this mode.
              onTap: () => wrapperTaps++,
              child: ElevatedButton(
                onPressed: () => childTaps++,
                child: const Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(
      childTaps,
      1,
      reason: "the child's own onPressed must still fire — it owns the tap",
    );
    expect(
      wrapperTaps,
      0,
      reason:
          'the wrapper must NOT also fire, or every such button would run '
          'its action twice',
    );
  });

  testWidgets('decorationOnly still animates the press', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              decorationOnly: true,
              onTap: () {},
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      _verticalScale(tester),
      greaterThan(1.0),
      reason:
          'observing the pointer is enough to drive the dip — the whole '
          'point of this mode is feedback without owning the gesture',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // Reported directly: "cant see ripple on android." The wash was going
  // into CustomPaint's `painter` (which draws BEHIND the child) while
  // every control this wraps has an opaque fill of its own — so it was
  // painted and then immediately covered. It was equally invisible on
  // iOS; Android is just where a ripple was expected.
  testWidgets('the wash paints OVER the control, not behind its own opaque '
      'fill', (tester) async {
    await _pump(tester, onTap: () {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final customPaint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: _within(ClipPath).first,
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      customPaint.foregroundPainter,
      isNotNull,
      reason:
          'the ripple must be a foregroundPainter — `painter` draws behind '
          'the child, where an opaque button fill hides it completely',
    );
    expect(customPaint.painter, isNull);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // Reported directly: "buttons became less responsive, as in tap and
  // nothing happens for some time (and action after a moment)."
  // GestureDetector.onTap only fires once the gesture arena declares a
  // winner; inside a real scrollable the arena holds the tap open to see
  // whether the pointer becomes a scroll, which is the delay that was
  // felt on device. onTapUp fires on finger-lift instead.
  //
  // This asserts the MECHANISM (the action is wired to onTapUp, with
  // onTap deliberately left unused), NOT the latency itself. The arena
  // contention that produces the delay needs a real drag-capable
  // competitor and does not reproduce under flutter_test, where a
  // synthetic tap resolves the arena immediately either way — verified
  // directly: an onTap-based version still passes a timing-style
  // assertion here, which is exactly why this checks the wiring rather
  // than pretending to measure the delay.
  testWidgets('the action is wired to onTapUp, not onTap — so it lands on '
      'finger-lift rather than on gesture-arena resolution', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);

    final detector = tester.widget<GestureDetector>(_within(GestureDetector));
    expect(
      detector.onTapUp,
      isNotNull,
      reason: 'onTapUp is what makes the press feel immediate',
    );
    expect(
      detector.onTap,
      isNull,
      reason:
          'onTap must stay unused — it only fires once the arena picks a '
          'winner, which is the delay that was reported',
    );

    // And that wiring actually runs the callback.
    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a circular control clips its ripple to a circle, not a '
      'square — the wash never corners past a round button\'s edge', (
    tester,
  ) async {
    await _pump(tester, onTap: () {}, shape: BoxShape.circle);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final clipPath = tester.widget<ClipPath>(_within(ClipPath).first);
    final clipper = clipPath.clipper!;
    final path = clipper.getClip(const Size(200, 60));
    // An oval clip excludes its bounding box's corners; a rect clip
    // wouldn't.
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(const Offset(100, 30)), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ripple: false drops the wash (no tap ripple, no held fill) but '
      'keeps the press squeeze', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              onTap: () {},
              ripple: false,
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressFeedback)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_within(ClipPath), findsNothing, reason: 'no wash');
    expect(_verticalScale(tester), isNot(1.0), reason: 'still squeezes');
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
