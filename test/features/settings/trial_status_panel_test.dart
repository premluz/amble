import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/features/settings/trial_status_panel.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/purchases_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Requested directly: "on settings first section... 21 days left / Get
/// Rios now > trigger paywall." Covers the trial-remaining copy, the
/// expired-trial copy, the button's paywall trigger, and that the whole
/// panel disappears once `panta_pro` is active.
void main() {
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_trial_status_panel');
    preferencesBox = await Hive.openBox<dynamic>(
      'test_preferences_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await preferencesBox.close();
  });

  // Real Hive disk I/O (preferencesBox.put) hangs indefinitely if awaited
  // directly inside a testWidgets callback body — flutter_test's
  // synchronous pump-based zone can starve it. Wrapped in runAsync, same
  // established pattern as every other real-Hive-write test in this repo
  // (see docs/ERROR_LOG.md).
  Future<void> pumpPanel(
    WidgetTester tester, {
    DateTime? installDate,
    required bool isPro,
  }) async {
    if (installDate != null) {
      await tester.runAsync(
        () => preferencesBox.put(
          PreferenceKeys.installDate,
          installDate.toIso8601String(),
        ),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          isPantaProProvider.overrideWithValue(isPro),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TrialStatusPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install (day 0) shows 21 days left', (tester) async {
    await pumpPanel(tester, isPro: false);

    expect(find.text('21 days left'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Get Rios now'), findsOneWidget);
  });

  testWidgets('mid-trial shows the correct singular/plural day count', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      installDate: DateTime.now().subtract(const Duration(days: 20)),
      isPro: false,
    );

    expect(find.text('1 day left'), findsOneWidget);
  });

  testWidgets('an expired trial shows the ended copy, not a day count', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      installDate: DateTime.now().subtract(const Duration(days: 30)),
      isPro: false,
    );

    expect(find.text('Your free trial has ended'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Get Rios now'), findsOneWidget);
  });

  testWidgets('with panta_pro active, the whole panel renders nothing', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      installDate: DateTime.now().subtract(const Duration(days: 30)),
      isPro: true,
    );

    expect(find.text('Get Rios now'), findsNothing);
    expect(find.textContaining('days left'), findsNothing);
    expect(find.text('Your free trial has ended'), findsNothing);
  });

  testWidgets(
    'tapping Get Rios now attempts to present the paywall — this test '
    'binary has no RevenueCat API keys, so it falls back to the '
    'unavailable message rather than reaching the SDK',
    (tester) async {
      await pumpPanel(tester, isPro: false);

      await tester.tap(find.widgetWithText(AppButton, 'Get Rios now'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('purchases are not available'),
        findsOneWidget,
      );

      // The toast's own auto-dismiss is a real platform Timer —
      // pumpAndSettle does not wait it out (it only settles animation
      // frames), so it's pumped explicitly here to fire before teardown,
      // matching zone_list_screen_test.dart's own established fix for the
      // same AppUndoToast pending-timer assertion.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    },
  );
}
