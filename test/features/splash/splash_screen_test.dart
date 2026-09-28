import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/splash/splash_carousel_screen.dart'
    show SplashLogo;
import 'package:amble/features/splash/splash_screen.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

/// Covers the new one-off splash — logo, headline, and a single CTA that
/// marks [HasSeenSplash] the same way [SplashCarouselScreen]'s own CTA
/// does, since the two share that preference as their "already shown"
/// state (see `splash_screen.dart`'s own doc comment).
void main() {
  late Box<dynamic> prefsBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_splash_screen');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
  });

  tearDown(() async {
    await prefsBox.deleteFromDisk();
  });

  Future<void> pumpSplash(WidgetTester tester, {VoidCallback? onFinished}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(
              HivePreferencesRepository(prefsBox),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: SplashScreen(onFinished: onFinished ?? () {}),
          ),
        ),
      );

  testWidgets('shows the logo, headline, and a single Start now CTA', (
    tester,
  ) async {
    await pumpSplash(tester);

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Start now'), findsOneWidget);
    // No carousel chrome — no Skip/Back, no page dots.
    expect(find.text('Skip'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  // Regression for the reported "yellow underline on every splash text":
  // this screen is handed directly to MaterialApp.home with no
  // Scaffold/Material ancestor, so `Text.build` used to merge every
  // Text's own style onto MaterialApp's `_errorTextStyle` fallback
  // (yellow double underline, `framework/material/app.dart`) instead of
  // an ordinary inherited default — `TextStyle.merge` only overrides
  // fields the child explicitly sets, and none of this screen's own
  // styles set `decoration`, so the fallback's underline survived
  // untouched. Checking `Text.style` directly wouldn't catch this (that's
  // the style PASSED IN, before the merge) — this asserts the actual
  // ambient `DefaultTextStyle` a Text under this screen resolves against,
  // which is what the Material wrapper fixes.
  testWidgets(
    'the ambient DefaultTextStyle is not MaterialApp\'s no-Material error style',
    (tester) async {
      await pumpSplash(tester);

      final headlineElement = tester.element(
        find.text('Less time planning,\nmore time living.'),
      );
      final ambientStyle = DefaultTextStyle.of(headlineElement).style;
      expect(ambientStyle.decoration, isNot(TextDecoration.underline));
      expect(ambientStyle.decorationColor, isNot(const Color(0xFFFFFF00)));
    },
  );

  testWidgets('tapping Start now marks the splash seen and calls onFinished', (
    tester,
  ) async {
    var finished = false;
    await pumpSplash(tester, onFinished: () => finished = true);

    // `_start()` awaits a real Hive write (`HasSeenSplash.markSeen`) before
    // calling `onFinished` — real disk I/O hangs indefinitely under
    // flutter_test's synchronous pump-based zone unless run inside
    // `runAsync`, per docs/ERROR_LOG.md and
    // splash_carousel_screen_test.dart's own "tapping Skip" test.
    await tester.runAsync(() async {
      await tester.tap(find.text('Start now'));
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    expect(finished, isTrue);
    expect(
      HivePreferencesRepository(
        prefsBox,
      ).getValue<bool>(PreferenceKeys.hasSeenSplash),
      isTrue,
    );
  });

  // Requested directly ("2 svg used per mode light dark... let's serve
  // correct logo on modes") — SplashLogo (shared by SplashScreen and
  // SplashCarouselScreen) must pick the SVG matching the ambient theme
  // brightness, not always the same file.
  group('SplashLogo picks the SVG matching the ambient brightness', () {
    Future<void> pumpLogo(WidgetTester tester, Brightness brightness) =>
        tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              useMaterial3: true,
              extensions: [
                brightness == Brightness.dark
                    ? AmbleTheme.dark
                    : AmbleTheme.light,
              ],
            ),
            home: Builder(
              builder: (context) => SplashLogo(
                theme: Theme.of(context).extension<AmbleTheme>()!,
              ),
            ),
          ),
        );

    testWidgets('light theme renders Logo_on_light.svg', (tester) async {
      await pumpLogo(tester, Brightness.light);

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/branding/Logo_on_light.svg',
      );
    });

    testWidgets('dark theme renders Logo_on_dark.svg', (tester) async {
      await pumpLogo(tester, Brightness.dark);

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/branding/Logo_on_dark.svg',
      );
    });
  });
}
