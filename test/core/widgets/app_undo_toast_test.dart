import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_undo_toast.dart';

void main() {
  testWidgets('AppUndoToast.show renders the message and Undo action', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppUndoToast.show(
      context: capturedContext,
      message: 'Created test task',
      onUndo: () {},
      duration: const Duration(seconds: 1),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Created test task'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Let the toast's own expiry timer/animation finish cleanly so the
    // test doesn't leave a pending timer behind.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  // Requested directly: "let's build undo change mechanism" — real bug
  // found and fixed while building it (2026-09-22): tapping Undo used to
  // remove the toast's OverlayEntry but never cancelled the underlying
  // platform Timer behind its own `Future.delayed` auto-dismiss, which
  // stayed pending and fired anyway (a harmless no-op in production,
  // guarded by its own `mounted` check, but `flutter_test`'s own teardown
  // treats ANY still-pending Timer as an assertion failure). This test
  // deliberately does NOT pump past `duration` afterward — if the Timer
  // were still alive, this test would fail on teardown even though every
  // assertion inside it passed.
  testWidgets(
    'tapping Undo cancels the auto-dismiss timer, not just the overlay',
    (tester) async {
      late BuildContext capturedContext;
      var undone = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      AppUndoToast.show(
        context: capturedContext,
        message: 'Removed test task',
        onUndo: () => undone = true,
        // Deliberately long — if the Timer weren't actually cancelled,
        // this test would hang the full suite waiting for the invariant
        // check rather than failing fast.
        duration: const Duration(seconds: 30),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(undone, isTrue);
      expect(find.text('Undo'), findsNothing);
      // No further pump()s past `duration` here — the whole point of this
      // test is that none are needed.
    },
  );
}
