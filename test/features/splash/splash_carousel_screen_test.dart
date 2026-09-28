import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/features/splash/splash_carousel_screen.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';

/// Covers the 2026-09-19 carousel refinement — requested directly: Skip
/// moved top-right, a Back arrow added top-left (hidden on the first
/// slide, matching Skip's existing hidden-on-last-slide pattern), and
/// each slide gaining optional image/video support (icon-in-circle stays
/// the fallback — untested here directly since no slide currently
/// supplies media, per the screen's own placeholder-content doc comment).
void main() {
  late Box<dynamic> prefsBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_splash_carousel');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
  });

  tearDown(() async {
    await prefsBox.deleteFromDisk();
  });

  Future<void> pumpCarousel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: SplashCarouselScreen(onFinished: () {}),
        ),
      ),
    );
    // Clears the timed splash logo (see SplashCarouselScreen's own
    // _splashDuration) so every test starts on the carousel itself.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
  }

  testWidgets('the first slide shows Skip but no Back button', (
    tester,
  ) async {
    await pumpCarousel(tester);

    expect(find.text('Skip'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  // Regression for the reported "yellow underline on every splash text":
  // this screen is handed directly to MaterialApp.home with no
  // Scaffold/Material ancestor, so `Text.build` used to merge every
  // slide's own style onto MaterialApp's `_errorTextStyle` fallback
  // (yellow double underline, `framework/material/app.dart`) rather than
  // an ordinary inherited default. Checking `Text.style` directly
  // wouldn't catch this (that's the style PASSED IN, before the merge) —
  // this asserts the actual ambient `DefaultTextStyle` a slide's own Text
  // resolves against, which is what the Material wrapper fixes.
  testWidgets(
    'the ambient DefaultTextStyle is not MaterialApp\'s no-Material error style',
    (tester) async {
      await pumpCarousel(tester);

      final headlineElement = tester.element(
        find.text('See your day, not just your list'),
      );
      final ambientStyle = DefaultTextStyle.of(headlineElement).style;
      expect(ambientStyle.decoration, isNot(TextDecoration.underline));
      expect(ambientStyle.decorationColor, isNot(const Color(0xFFFFFF00)));
    },
  );

  testWidgets('swiping to a middle slide shows both Back and Skip', (
    tester,
  ) async {
    await pumpCarousel(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('tapping Back returns to the previous slide', (tester) async {
    await pumpCarousel(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('the last slide shows Back but no Skip, and the CTA reads '
      '"Get started"', (tester) async {
    await pumpCarousel(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Skip'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Skip and Back both render as the ghost variant', (
    tester,
  ) async {
    await pumpCarousel(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final skipButton = tester.widgetList<AppButton>(find.byType(AppButton)).firstWhere(
      (b) => b.label == 'Skip',
    );
    final backButton = tester.widgetList<AppButton>(find.byType(AppButton)).firstWhere(
      (b) => b.icon == Icons.arrow_back_rounded,
    );

    expect(skipButton.variant, AppButtonVariant.ghost);
    expect(backButton.variant, AppButtonVariant.ghost);
    expect(backButton.shape, AppButtonShape.circle);
  });

  testWidgets('tapping Skip marks the splash seen', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: SplashCarouselScreen(onFinished: () => finished = true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();

    // `_finish()` awaits a real Hive write (`HasSeenSplash.markSeen`)
    // before calling `onFinished` — real disk I/O hangs indefinitely under
    // flutter_test's synchronous pump-based zone unless run inside
    // `runAsync`, per docs/ERROR_LOG.md. Copying `_tapAndSettle`'s exact
    // established shape (tap, pump, drain, pumpAndSettle, all inside ONE
    // runAsync block) rather than reconstructing it from description —
    // that file's own lesson, learned the hard way twice already.
    await tester.runAsync(() async {
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    expect(finished, isTrue);
  });
}
