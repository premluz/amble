import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/quick_create_sheet_shell.dart';

void main() {
  group('QuickCreateSheetHeightController', () {
    QuickCreateSheetHeightController small() {
      final controller = QuickCreateSheetHeightController(
        initialFraction: quickCreateSheetMinFraction,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('starts at the given initial fraction, not minimised', () {
      final controller = small();
      expect(controller.fraction, quickCreateSheetMinFraction);
      expect(controller.minimised, isFalse);
    });

    test('updateFraction() never goes above small — the sheet does not '
        'expand (2026-09-30) — but may go BELOW it mid-drag, for the '
        'drag-down-to-close gesture', () {
      final controller = small();

      controller.updateFraction(5);
      expect(controller.fraction, quickCreateSheetMinFraction);

      controller.updateFraction(-5);
      expect(controller.fraction, 0.0);

      // Below the small floor, but not clamped there — the "still
      // mid-drag toward closing" state settle() reads.
      controller.updateFraction(0.1);
      expect(controller.fraction, 0.1);
    });

    test('a fast upward FLICK returns to small, from minimised too — never '
        'larger', () {
      final controller = small();
      expect(controller.settle(velocity: -1200), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);

      controller.minimise();
      expect(controller.settle(velocity: -1200), isFalse);
      expect(controller.minimised, isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
    });

    // Three states (2026-09-16): a downward flick steps DOWN one state at a
    // time, small -> minimised -> closed, so the minimised state can't be
    // skipped past by a fast gesture.
    test('a fast downward FLICK steps down one state, it does not close', () {
      final controller = small();
      expect(controller.settle(velocity: 1200), isFalse);
      expect(controller.minimised, isTrue);
      expect(controller.fraction, quickCreateSheetMinimisedFraction);

      expect(controller.settle(velocity: 1200), isTrue);
    });

    test('a slow release is decided by distance, not velocity', () {
      final controller = small();
      controller.updateFraction(quickCreateSheetMinFraction - 0.01);
      expect(controller.settle(velocity: -50), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
    });

    test('settle() reports true (close) once the fraction is dragged far '
        'enough below the MINIMISED floor', () {
      final controller = small();

      // Well below the small floor — still only minimises.
      controller.updateFraction(0.05);
      expect(controller.settle(), isFalse);
      expect(controller.minimised, isTrue);

      // A second drag down, now past the minimised floor's close threshold.
      controller.updateFraction(0.02);
      expect(controller.settle(), isTrue);
    });

    test('settle() does NOT report close for a small overshoot just below '
        'the floor — only a real drag-down counts', () {
      final controller = small();
      controller.updateFraction(quickCreateSheetMinFraction - 0.01);
      expect(controller.settle(), isFalse);
      expect(controller.fraction, quickCreateSheetMinFraction);
    });

    test('notifies listeners on every state-changing call', () {
      final controller = small();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateFraction(0.2);
      controller.settle();
      controller.restoreToSmall();

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

    testWidgets('dragging down lowers the controller\'s fraction', (
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
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();

      expect(controller.fraction, lessThan(quickCreateSheetMinFraction));

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
        quickCreateSheetMinFraction,
        reason: 'an upward drag settles back at small — it never expands',
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
