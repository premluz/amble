import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_drag_to_close_handle.dart';

/// Covers the shared drag-to-close handle extracted from
/// `quick_capture_sheet.dart`'s and `new_zone_sheet.dart`'s own
/// near-identical hand-rolled gesture code. Reported directly: "the
/// handle pattern in sheets should be responsive when grabbed to drag,
/// similar to quick create task on timeline... new zone doesn't [respond]
/// and at some point triggers close." See docs/DESIGN_SYSTEM.md's
/// "Sheets > Drag handle" section for the documented contract.
void main() {
  late AppDragToCloseController controller;
  var closed = false;

  setUp(() {
    controller = AppDragToCloseController();
    closed = false;
  });

  tearDown(() => controller.dispose());

  Future<void> pumpHandle(
    WidgetTester tester, {
    bool responsive = true,
    double? closeDistance,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: AppDragToCloseHandle(
            theme: AmbleTheme.light,
            controller: controller,
            responsive: responsive,
            closeDistance: closeDistance,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
  }

  /// Drags the handle down by [dy] in small steps (matching
  /// `app_swipe_actions_test.dart`'s own reasoning: a single `drag` call
  /// loses `kTouchSlop` worth of distance to the recognizer's own
  /// acceptance, understating how far the finger actually travelled) and
  /// leaves the pointer down, so a caller can inspect live state or keep
  /// moving before deciding to release.
  Future<TestGesture> dragAndHold(WidgetTester tester, double dy) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppDragToCloseHandle)),
    );
    const step = 20.0;
    final steps = (dy.abs() / step).ceil();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, step * dy.sign));
      await tester.pump();
    }
    await gesture.moveBy(Offset(0, kTouchSlop * dy.sign));
    await tester.pump();
    return gesture;
  }

  group('responsive (the default)', () {
    testWidgets('the sheet visually follows the finger DURING the drag — the '
        'regression this whole widget exists to fix', (tester) async {
      await pumpHandle(tester);
      expect(controller.offset, 0);

      await dragAndHold(tester, 40);

      expect(
        controller.offset,
        greaterThan(0),
        reason:
            'a responsive handle must publish live offset while still '
            'being dragged, not stay silent until release',
      );
    });

    testWidgets(
      'releasing SHORT of the close threshold snaps the offset back to '
      'zero rather than leaving the sheet stuck displaced',
      (tester) async {
        await pumpHandle(tester, closeDistance: 100);
        final gesture = await dragAndHold(tester, 30);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(closed, isFalse);
        expect(controller.offset, 0);
      },
    );

    testWidgets('releasing PAST the close threshold fires onClose', (
      tester,
    ) async {
      await pumpHandle(tester, closeDistance: 40);
      final gesture = await dragAndHold(tester, 80);
      await gesture.up();
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets(
      'a fast downward flick closes even without reaching the distance '
      'threshold',
      (tester) async {
        // A large `closeDistance` isolates the velocity path — `fling`'s
        // own gesture simulation needs real travel distance to reach a
        // measured velocity anywhere near what's requested (a very short
        // flick doesn't reach it), so this uses a generous offset while
        // keeping `closeDistance` well above it, so closing here can only
        // be the velocity half of the OR firing, not the distance half.
        await pumpHandle(tester, closeDistance: 2000);
        await tester.fling(
          find.byType(AppDragToCloseHandle),
          const Offset(0, 200),
          1200,
        );
        await tester.pump();

        expect(
          closed,
          isTrue,
          reason: 'a fast flick must close on velocity alone',
        );
      },
    );
  });

  group('non-responsive (the opt-out toggle)', () {
    testWidgets('the controller offset stays at zero throughout the drag — the '
        'previous behavior every existing caller had before this widget', (
      tester,
    ) async {
      await pumpHandle(tester, responsive: false);

      final gesture = await dragAndHold(tester, 40);
      expect(
        controller.offset,
        0,
        reason: 'non-responsive mode must never publish a live offset',
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets('still closes past the threshold on release, identically to '
        'responsive mode — only the live feedback differs, not the '
        'close decision', (tester) async {
      await pumpHandle(tester, responsive: false, closeDistance: 40);
      final gesture = await dragAndHold(tester, 80);
      await gesture.up();
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('still does nothing when released short of the threshold', (
      tester,
    ) async {
      await pumpHandle(tester, responsive: false, closeDistance: 100);
      final gesture = await dragAndHold(tester, 30);
      await gesture.up();
      await tester.pump();

      expect(closed, isFalse);
    });
  });

  testWidgets('AppDragToCloseController starts at offset zero', (tester) async {
    expect(AppDragToCloseController().offset, 0);
  });
}
