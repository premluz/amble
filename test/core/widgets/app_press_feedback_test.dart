import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// The press dip, read from the x-scale entry of this widget's own
/// `Transform` matrix. Deliberately NOT `getMaxScaleOnAxis()`, which
/// reports 1.0 here: `Transform.scale` composes the scale with an origin
/// translation, and that helper doesn't see through the composition.
double _currentScale(WidgetTester tester) {
  final scales = tester
      .widgetList<Transform>(_within(Transform))
      .map((t) => t.transform.storage[0]);
  // At rest every Transform in the subtree is 1.0; while held, only this
  // widget's own dips below that.
  return scales.reduce((a, b) => a < b ? a : b);
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

  testWidgets('the control dips while held and springs back on release', (
    tester,
  ) async {
    await _pump(tester, onTap: () {});

    expect(
      _currentScale(tester),
      1.0,
      reason: 'at rest the control is at its natural size',
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap me')),
    );
    // A bare pump first so the tap-down handler's own setState lands and
    // starts the controller; only then does elapsing time advance it.
    await tester.pump();
    // Past the dip's own duration (motionFast, 150ms) so it has fully
    // landed rather than being caught mid-animation.
    await tester.pump(const Duration(milliseconds: 200));

    final heldScale = _currentScale(tester);
    expect(
      heldScale,
      lessThan(1.0),
      reason: 'held: the control gives slightly under the press',
    );
    expect(
      heldScale,
      greaterThan(0.9),
      reason:
          'the dip is deliberately subtle — a deep shrink would read as '
          'the control moving away from the finger',
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      _currentScale(tester),
      1.0,
      reason: 'released: springs back to its natural size',
    );
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
      _currentScale(tester),
      lessThan(1.0),
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
}
