import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_sheet.dart';
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

  testWidgets('the toast is see-through glass: the shared floating glass, '
      'its fill thinned', (tester) async {
    final theme = AmbleTheme.light;
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
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
      message: "Moved 'Gym'",
      onUndo: () {},
      duration: const Duration(seconds: 1),
    );
    await tester.pump();
    await tester.pump();

    final surface = tester.widget<AppFloatingSurface>(
      find.byType(AppFloatingSurface),
    );
    expect(surface.material, FloatingMaterial.glass);
    expect(surface.surfaceColor, ToastTokens.fill(theme));
    expect(surface.surfaceColor!.a, lessThan(1));
    expect(
      tester.widget<Text>(find.text("Moved 'Gym'")).style?.color,
      theme.colorTextPrimary,
      reason: 'normal text on glass, not inverted',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('a sheet is painted above an active toast', (tester) async {
    late BuildContext capturedContext;
    var undone = false;
    var sheetTapped = false;

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
      message: 'Moved task',
      onUndo: () => undone = true,
      duration: const Duration(seconds: 30),
    );
    await tester.pump();
    await tester.pump();

    unawaited(
      AppSheet.show<void>(
        context: capturedContext,
        builder: (context) => GestureDetector(
          key: const ValueKey('sheet-action'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            sheetTapped = true;
            Navigator.of(context).pop();
          },
          child: const SizedBox(
            width: double.infinity,
            height: 180,
            child: Center(child: Text('Sheet action')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sheet-action')));
    await tester.pump();

    expect(sheetTapped, isTrue);
    expect(undone, isFalse);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
  });
}
