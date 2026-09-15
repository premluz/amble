import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/haptics.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';

class _RecordingHaptics implements Haptics {
  final played = <AmbleHaptic>[];

  @override
  void play(AmbleHaptic haptic) => played.add(haptic);
}

const _extent = 72.0;

/// Past `extent * 2` (the activate threshold), so a release here fires.
///
/// Delivered via [swipeBy] rather than `tester.drag`: the horizontal
/// recognizer consumes `kTouchSlop` before it accepts the gesture at all,
/// so a single `drag` of exactly this distance moves the row only
/// `distance - kTouchSlop` and lands SHORT of the threshold. Measured
/// directly — six incremental moves of -30 reached it while one drag of
/// -152 did not.
const _pastThreshold = _extent * 2 + 8;

/// Enough to park open at stage one, but nowhere near the threshold.
const _toParked = _extent;

void main() {
  late List<String> fired;
  late _RecordingHaptics haptics;

  setUp(() {
    fired = [];
    haptics = _RecordingHaptics();
  });

  Future<void> pumpRow(
    WidgetTester tester, {
    VoidCallback? onInnerTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: AppSwipeActions(
            extent: _extent,
            haptics: haptics,
            startAction: AppSwipeAction(
              icon: Icons.calendar_today_rounded,
              background: AmbleTheme.light.colorAccent,
              semanticLabel: 'Schedule',
              onActivate: () => fired.add('schedule'),
            ),
            endAction: AppSwipeAction(
              icon: Icons.delete_outline_rounded,
              background: AmbleTheme.light.colorTaskAlert,
              semanticLabel: 'Remove',
              destructive: true,
              onActivate: () => fired.add('remove'),
            ),
            child: GestureDetector(
              onTap: onInnerTap ?? () => fired.add('row'),
              child: const SizedBox(
                height: 64,
                width: double.infinity,
                child: Text('Buy milk'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Drags [dx] horizontally in small steps, so the slop the recognizer
  /// swallows up front doesn't silently shorten the travel (see
  /// [_pastThreshold]). The row is the only Transform above the child, so
  /// its text's own left edge is an honest read of the offset.
  /// Drags [dx] in small steps and leaves the pointer DOWN, so a caller
  /// can keep moving before deciding to release. [swipeBy] is the ordinary
  /// press-move-release wrapper around this.
  Future<TestGesture> swipeAndHold(WidgetTester tester, double dx) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Buy milk')),
    );
    const step = 20.0;
    final steps = (dx.abs() / step).ceil();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(step * dx.sign, 0));
      await tester.pump();
    }
    // One extra move covering the slop the recognizer ate before accepting.
    await gesture.moveBy(Offset(kTouchSlop * dx.sign, 0));
    await tester.pump();
    return gesture;
  }

  Future<void> swipeBy(WidgetTester tester, double dx) async {
    final gesture = await swipeAndHold(tester, dx);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// The row's own horizontal displacement — the honest read of whether it
  /// is parked open, rather than inferring from whether an icon is findable.
  double rowOffset(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.text('Buy milk'),
            matching: find.byType(Transform),
          )
          .first,
    );
    return transform.transform.getTranslation().x;
  }

  group('stage one — release parks the row open', () {
    testWidgets('a short swipe right parks open without firing schedule', (
      tester,
    ) async {
      await pumpRow(tester);

      await tester.drag(find.text('Buy milk'), const Offset(_toParked, 0));
      await tester.pumpAndSettle();

      expect(fired, isEmpty, reason: 'stage one must not activate');
      expect(rowOffset(tester), moreOrLessEquals(_extent, epsilon: 0.5));
    });

    testWidgets('a short swipe left parks open without firing remove', (
      tester,
    ) async {
      await pumpRow(tester);

      await tester.drag(find.text('Buy milk'), const Offset(-_toParked, 0));
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
      expect(rowOffset(tester), moreOrLessEquals(-_extent, epsilon: 0.5));
    });

    testWidgets('a barely-there swipe snaps shut instead of parking', (
      tester,
    ) async {
      await pumpRow(tester);

      // Under half the resting extent — an aborted swipe, not an intent.
      // Driven directly rather than via swipeBy, whose slop top-up would
      // push this past the parking point it is meant to stay under.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Buy milk')),
      );
      await gesture.moveBy(const Offset(kTouchSlop + 8, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
      expect(rowOffset(tester), moreOrLessEquals(0, epsilon: 0.5));
    });
  });

  group('stage two — continuing past the threshold activates on release', () {
    testWidgets('swiping right past the threshold fires schedule and closes', (
      tester,
    ) async {
      await pumpRow(tester);

      await swipeBy(tester, _pastThreshold);

      expect(fired, ['schedule']);
      expect(
        rowOffset(tester),
        moreOrLessEquals(0, epsilon: 0.5),
        reason: 'activating must snap the row shut, not leave it parked',
      );
    });

    testWidgets('swiping left past the threshold fires remove and closes', (
      tester,
    ) async {
      await pumpRow(tester);

      await swipeBy(tester, -_pastThreshold);

      expect(fired, ['remove']);
      expect(rowOffset(tester), moreOrLessEquals(0, epsilon: 0.5));
    });

    testWidgets('arming a DESTRUCTIVE action plays the heavier warning '
        'haptic, a constructive one only selection', (tester) async {
      await pumpRow(tester);

      await swipeBy(tester, -_pastThreshold);
      expect(haptics.played, contains(AmbleHaptic.warning));
      expect(haptics.played, isNot(contains(AmbleHaptic.selection)));

      haptics.played.clear();
      await swipeBy(tester, _pastThreshold);
      expect(haptics.played, contains(AmbleHaptic.selection));
      expect(haptics.played, isNot(contains(AmbleHaptic.warning)));
    });

    testWidgets('the arming haptic fires ONCE per crossing, not on every '
        'pointer move past the threshold', (tester) async {
      await pumpRow(tester);

      // Driven through the same helper as every other stage-two case, so
      // the threshold is genuinely crossed — a hand-rolled sequence here
      // was shortened by slop and never crossed at all, counting zero.
      final gesture = await swipeAndHold(tester, -_pastThreshold);
      // Three more moves, all still past the threshold. Small enough that
      // the row stays inside its own clamp (threshold + extent), so every
      // one of them genuinely re-enters the past-threshold branch rather
      // than being absorbed by the limit.
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(-4, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        haptics.played.where((h) => h == AmbleHaptic.warning).length,
        1,
        reason: 'a repeated haptic on every move would buzz continuously',
      );
    });
  });

  // The regression this widget's gesture-ownership note exists to prevent:
  // the Inbox row carries three separate inner tap targets, and a swipe
  // wrapper that claimed taps would silently kill all of them.
  group('the child keeps its own gestures', () {
    testWidgets('tapping the row still reaches the child, both at rest and '
        'while parked open', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.text('Buy milk'));
      await tester.pump();
      expect(fired, ['row']);

      await tester.drag(find.text('Buy milk'), const Offset(-_toParked, 0));
      await tester.pumpAndSettle();
      fired.clear();

      await tester.tap(find.text('Buy milk'), warnIfMissed: false);
      await tester.pump();
      expect(
        fired,
        ['row'],
        reason: 'a parked-open row must still expose its inner tap targets',
      );
    });

    // The gap that let a real defect ship: every case above either swipes
    // a row with no inner tap, or taps a row without swiping. The Inbox
    // row has three inner tap targets AND must swipe, and a plain
    // GestureDetector here meant the child won the arena on every press
    // and the row never moved at all — measured at zero pixels of travel
    // through a full swipe. This asserts the combination directly.
    testWidgets('a row that owns its OWN tap can still be swiped — the '
        'child winning a stationary press must not starve the drag', (
      tester,
    ) async {
      await pumpRow(tester);

      await swipeBy(tester, -_pastThreshold);

      expect(
        fired,
        ['remove'],
        reason: 'the swipe must still activate on a row with inner taps',
      );
    });

    testWidgets('a vertical drag is left to the enclosing scrollable', (
      tester,
    ) async {
      await pumpRow(tester);

      await tester.drag(find.text('Buy milk'), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
      expect(rowOffset(tester), moreOrLessEquals(0, epsilon: 0.5));
    });
  });
}
