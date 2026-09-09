import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/quick_create_sheet_shell.dart';

void main() {
  group('QuickCreateSheetHeightController', () {
    test('starts at the given initial fraction, not expanded', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      expect(controller.fraction, quickCreateSheetMinFraction);
      expect(controller.expanded, isFalse);
    });

    test('updateFraction() clamps to [0.0, 1.0] — allowed to go BELOW '
        'the small floor mid-drag, for the drag-down-to-close gesture', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      controller.updateFraction(-5);
      expect(controller.fraction, 0.0);

      controller.updateFraction(5);
      expect(controller.fraction, 1.0);

      controller.updateFraction(0.6);
      expect(controller.fraction, 0.6);

      // Below the small floor, but not clamped there — this is the
      // "still mid-drag toward closing" state settle() reads.
      controller.updateFraction(0.1);
      expect(controller.fraction, 0.1);
    });

    test('settle() expands from only a SHORT pull above the floor — not '
        'the old half-the-screen midpoint, reported directly as '
        '"difficult to do"', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      // A modest pull, nowhere near the small/full midpoint (0.61) that
      // the previous rule demanded.
      controller.updateFraction(quickCreateSheetMinFraction + 0.1);
      expect(controller.settle(), isFalse);
      expect(controller.fraction, 1.0);
      expect(controller.expanded, isTrue);
    });

    test('settle() snaps back to the small floor when the pull was too '
        'small to count', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      controller.updateFraction(quickCreateSheetMinFraction + 0.01);
      expect(controller.settle(), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
      expect(controller.expanded, isFalse);
    });

    test('a fast upward FLICK expands regardless of how far it moved', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      // Barely moved at all — velocity alone decides.
      expect(controller.settle(velocity: -1200), isFalse);
      expect(controller.fraction, 1.0);
      expect(controller.expanded, isTrue);
    });

    test('a fast downward FLICK closes regardless of how far it moved', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      expect(controller.settle(velocity: 1200), isTrue);
    });

    test('a slow release is decided by distance, not velocity', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      controller.updateFraction(quickCreateSheetMinFraction + 0.01);
      // Below the flick threshold in both directions — distance wins.
      expect(controller.settle(velocity: -50), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
    });

    test('settle() reports true (close) once the fraction is dragged far '
        'enough below the small floor', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      // Well below the floor — past the close threshold.
      controller.updateFraction(0.05);
      expect(controller.settle(), isTrue);
    });

    test('settle() does NOT report close for a small overshoot just below '
        'the floor — only a real drag-down counts', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      // Just under the floor, within the threshold — a finger nudge, not
      // a deliberate close.
      controller.updateFraction(quickCreateSheetMinFraction - 0.01);
      expect(controller.settle(), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
    });

    test('expand() jumps straight to full regardless of current fraction', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      controller.expand();

      expect(controller.fraction, 1.0);
      expect(controller.expanded, isTrue);
    });

    test('notifies listeners on every state-changing call', () {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateFraction(0.5);
      controller.settle();
      controller.expand();

      expect(notifications, 3);
    });
  });

  group('QuickCreateSheetHandle', () {
    Future<void> pump(
      WidgetTester tester,
      QuickCreateSheetHeightController controller, {
      VoidCallback? onCloseRequested,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context).extension<AmbleTheme>()!;
              return Scaffold(
                body: QuickCreateSheetHandle(
                  theme: theme,
                  controller: controller,
                  viewportHeight: 800,
                  onCloseRequested: onCloseRequested ?? () {},
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('dragging up increases the controller\'s fraction', (
      tester,
    ) async {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);
      await pump(tester, controller);

      // A manual gesture (not tester.drag, which fires a complete
      // down->moves->up sequence in one call) so the mid-drag fraction can
      // be observed BEFORE onVerticalDragEnd's own settle() snaps it back
      // to a fixed height.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuickCreateSheetHandle)),
      );
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();

      expect(controller.fraction, greaterThan(quickCreateSheetMinFraction));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('releasing the drag calls settle() (snaps to a fixed '
        'height)', (tester) async {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);
      await pump(tester, controller);

      await tester.drag(
        find.byType(QuickCreateSheetHandle),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(
        controller.fraction,
        anyOf(quickCreateSheetMinFraction, 1.0),
        reason: 'settle() always lands on one of the two fixed heights',
      );
    });

    testWidgets(
      'dragging down past the close threshold fires onCloseRequested — '
      'requested directly ("the sheet should also be closing with this '
      'handle that expands it")',
      (tester) async {
        final controller = QuickCreateSheetHeightController(
          initialFraction: quickCreateSheetMinFraction,
        );
        addTearDown(controller.dispose);
        var closeRequested = false;
        await pump(
          tester,
          controller,
          onCloseRequested: () => closeRequested = true,
        );

        // A large downward drag, well past the close threshold.
        await tester.drag(
          find.byType(QuickCreateSheetHandle),
          const Offset(0, 300),
        );
        await tester.pump();

        expect(closeRequested, isTrue);
      },
    );

    testWidgets(
      'a small downward nudge (within the close threshold) settles back '
      'to the small height instead of closing',
      (tester) async {
        final controller = QuickCreateSheetHeightController(
          initialFraction: quickCreateSheetMinFraction,
        );
        addTearDown(controller.dispose);
        var closeRequested = false;
        await pump(
          tester,
          controller,
          onCloseRequested: () => closeRequested = true,
        );

        await tester.drag(
          find.byType(QuickCreateSheetHandle),
          const Offset(0, 10),
        );
        await tester.pump();

        expect(closeRequested, isFalse);
        expect(controller.fraction, quickCreateSheetMinFraction);
      },
    );
  });
}
