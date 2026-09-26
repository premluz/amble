import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_modal_route.dart';
import 'package:amble/core/widgets/app_sheet.dart';

/// **2026-09-22 — both routes now open/close with NO animation at all.**
/// Requested directly: "remove animation completely for switching
/// views... change screens no animation." This file used to assert the
/// "faster, modern" fade+slide entrance these routes were built with
/// (curve, mid-flight opacity/position, entrance-vs-dismissal duration
/// asymmetry) — see docs/DECISIONS.md's matching entry for that history.
/// With `transitionDuration`/`reverseTransitionDuration` now
/// `Duration.zero`, there is no intermediate frame left to sample
/// (`pushAppSheetRoute`/`pushFullScreenRoute` both still build the same
/// `FadeTransition`/`SlideTransition` tree, which resolves straight to
/// its end state on the very next frame) — this file now asserts the
/// stronger claim: exactly zero duration, both ways, for both routes.
Future<GlobalKey<NavigatorState>> _pumpHost(WidgetTester tester) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  return navigatorKey;
}

void main() {
  testWidgets('pushAppSheetRoute opens and closes instantly — no '
      'transition duration either way', (tester) async {
    final navigatorKey = await _pumpHost(tester);
    pushAppSheetRoute<void>(
      navigatorKey.currentContext!,
      (_) => const Text('Sheet'),
    );
    await tester.pump();

    expect(find.text('Sheet'), findsOneWidget);

    final route = ModalRoute.of(tester.element(find.text('Sheet')))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);

    navigatorKey.currentState!.pop();
    await tester.pump();
    expect(find.text('Sheet'), findsNothing);
  });

  // A prior keyboard must not leave a later plain sheet floating in empty space.
  testWidgets('plain sheets use only the current keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final navigatorKey = await _pumpHost(tester);
    Future<void> openSheet() async {
      AppSheet.show<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('Body')),
      );
      await tester.pumpAndSettle();
    }

    // Exercise a different keyboard state before reopening.
    await openSheet();
    final originalTop = tester.getRect(find.text('Body')).top;
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    // Reopening without a keyboard restores the original position.
    await openSheet();
    final beforeKeyboard = tester.getRect(find.text('Body')).top;
    expect(beforeKeyboard, originalTop);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    final afterKeyboard = tester.getRect(find.text('Body')).top;

    expect(
      afterKeyboard,
      beforeKeyboard - tester.view.viewInsets.bottom / tester.view.devicePixelRatio,
      reason: 'plain sheets track the current inset without a session-wide cache',
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });

  group('pushFullScreenRoute', () {
    testWidgets('is opaque — no scrim behind a full-screen page', (
      tester,
    ) async {
      final navigatorKey = await _pumpHost(tester);
      pushFullScreenRoute<void>(
        navigatorKey.currentContext!,
        (_) => const Text('Full screen'),
      );
      await tester.pump();

      final route =
          ModalRoute.of(tester.element(find.text('Full screen')))!
              as PageRouteBuilder;
      expect(
        route.opaque,
        isTrue,
        reason:
            'a full-screen page has nothing left showing behind it, so '
            'unlike the sheet it needs no barrierColor/scrim',
      );
    });

    testWidgets('opens and closes instantly — no transition duration '
        'either way, matching pushAppSheetRoute', (tester) async {
      final navigatorKey = await _pumpHost(tester);
      pushFullScreenRoute<void>(
        navigatorKey.currentContext!,
        (_) => const Text('Full screen'),
      );
      await tester.pump();

      expect(find.text('Full screen'), findsOneWidget);

      final route = ModalRoute.of(tester.element(find.text('Full screen')))!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);

      navigatorKey.currentState!.pop();
      await tester.pump();
      expect(find.text('Full screen'), findsNothing);
    });
  });
}
