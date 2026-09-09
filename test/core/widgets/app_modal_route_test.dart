import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_modal_route.dart';
import 'package:amble/core/widgets/app_sheet.dart';

/// Requested directly: "make animations of sheets more modern, faster,
/// smoother, kind of that they feel more responsive so fade in and move up
/// from 50% of position feeling more rapid with nice easing."
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
  final theme = AmbleTheme.light;

  testWidgets('the sheet fades in as it rises, rather than sliding in fully '
      'opaque', (tester) async {
    final navigatorKey = await _pumpHost(tester);
    pushAppSheetRoute<void>(
      navigatorKey.currentContext!,
      (_) => const Text('Sheet'),
    );

    // Part-way through the entrance the sheet must be partly transparent —
    // a plain slide would already be at full opacity here.
    await tester.pump();
    await tester.pump(theme.motionNormal ~/ 3);

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Sheet'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, greaterThan(0.0));
    expect(
      fade.opacity.value,
      lessThan(1.0),
      reason: 'the entrance fades — it is not a plain opaque slide',
    );

    await tester.pumpAndSettle();
    final settled = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Sheet'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(settled.opacity.value, 1.0);
  });

  testWidgets('the sheet starts half a screen up, not fully offscreen — so '
      'it travels less distance and reads as quicker', (tester) async {
    final navigatorKey = await _pumpHost(tester);
    pushAppSheetRoute<void>(
      navigatorKey.currentContext!,
      (_) => const Text('Sheet'),
    );

    // A hair into the transition rather than exactly t=0: at zero the
    // sheet is still fully transparent and its subtree isn't located by a
    // text finder yet. Early enough that the slide is still near its
    // start offset.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final slide = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text('Sheet'),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(
      slide.position.value.dy,
      closeTo(0.5, 0.05),
      reason:
          'a full-height slide would start at 1.0; starting at 0.5 halves '
          'the distance travelled, which is most of what makes the '
          'entrance feel rapid',
    );

    await tester.pumpAndSettle();
    final settled = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text('Sheet'),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(settled.position.value.dy, 0.0);
  });

  testWidgets('dismissal is quicker than the entrance — a sheet on its way '
      'out has nothing left to show', (tester) async {
    final navigatorKey = await _pumpHost(tester);
    pushAppSheetRoute<void>(
      navigatorKey.currentContext!,
      (_) => const Text('Sheet'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);

    navigatorKey.currentState!.pop();
    // Past the (shorter) reverse duration but NOT past the entrance's —
    // the sheet must already be gone.
    await tester.pump();
    await tester.pump(theme.motionFast + const Duration(milliseconds: 20));

    expect(
      find.text('Sheet'),
      findsNothing,
      reason:
          'reverseTransitionDuration is motionFast; if dismissal still ran '
          'at the entrance duration the sheet would linger here',
    );
  });

  // Reported directly: "the small sheet only opens to its height (fast as
  // we discussed) but then slower moving keyboard pushes it further...
  // can it actually get to the final position and keyboard follows up?"
  // Measured before the fix at a 300px second movement on an 800px-tall
  // screen. AppSheet now reserves the keyboard's REMEMBERED height, so
  // the sheet lands once and the keyboard rises behind it.
  testWidgets('a sheet opened after the keyboard has been seen once lands '
      'at its final position and does not move when the keyboard arrives', (
    tester,
  ) async {
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

    // First open teaches AppSheet the keyboard's height.
    await openSheet();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    // Second open: the reservation applies before any inset exists.
    await openSheet();
    final beforeKeyboard = tester.getRect(find.text('Body')).top;

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    final afterKeyboard = tester.getRect(find.text('Body')).top;

    expect(
      afterKeyboard,
      beforeKeyboard,
      reason:
          'the sheet must already sit above the keyboard — any difference '
          'here is the second shove the reservation exists to remove',
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });
}
