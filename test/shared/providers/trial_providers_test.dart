import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/purchases_providers.dart';
import 'package:amble/shared/providers/trial_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

/// Requested directly: "lock behind 21 day trial ability to add new tasks
/// via any route." Covers the pure trial-clock computation
/// (`daysSinceInstall`/`isInTrialPeriod`/`daysRemainingInTrial`) and the
/// combined `canCreateTask` check in isolation from `TaskList` itself —
/// see `task_providers_test.dart` for the "createTask/captureTask actually
/// throw" coverage.
void main() {
  late Box<dynamic> preferencesBox;
  late ProviderContainer container;

  Future<void> setInstallDate(DateTime date) async {
    await preferencesBox.put(
      PreferenceKeys.installDate,
      date.toIso8601String(),
    );
    container.invalidate(daysSinceInstallProvider);
  }

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_trial_providers');
    preferencesBox = await Hive.openBox<dynamic>(
      'test_preferences_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(preferencesBox),
        ),
        isPantaProProvider.overrideWithValue(false),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await preferencesBox.deleteFromDisk();
  });

  test(
    'daysSinceInstall is 0 when installDate was never recorded — errs '
    'toward not blocking a fresh install',
    () {
      expect(container.read(daysSinceInstallProvider), 0);
      expect(container.read(isInTrialPeriodProvider), isTrue);
    },
  );

  test('daysSinceInstall counts whole days since the recorded timestamp', () async {
    await setInstallDate(DateTime.now().subtract(const Duration(days: 5)));
    expect(container.read(daysSinceInstallProvider), 5);
  });

  test('isInTrialPeriod is true through day 20, false from day 21', () async {
    await setInstallDate(
      DateTime.now().subtract(const Duration(days: 20, hours: 1)),
    );
    expect(container.read(isInTrialPeriodProvider), isTrue);

    await setInstallDate(
      DateTime.now().subtract(const Duration(days: 21, hours: 1)),
    );
    expect(container.read(isInTrialPeriodProvider), isFalse);
  });

  test('daysRemainingInTrial floors at 0 once the trial has expired', () async {
    await setInstallDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    expect(container.read(daysRemainingInTrialProvider), 0);
  });

  test(
    'canCreateTask is true in trial even without panta_pro, false once '
    'expired without it, true again once panta_pro is active',
    () async {
      expect(container.read(canCreateTaskProvider), isTrue);

      await setInstallDate(
        DateTime.now().subtract(const Duration(days: 22)),
      );
      expect(container.read(canCreateTaskProvider), isFalse);

      container.updateOverrides([
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(preferencesBox),
        ),
        isPantaProProvider.overrideWithValue(true),
      ]);
      expect(container.read(canCreateTaskProvider), isTrue);
    },
  );

  test(
    'InstallDate.recordIfNeeded writes once and never overwrites an '
    'existing timestamp',
    () async {
      await container.read(installDateProvider.notifier).recordIfNeeded();
      final firstWrite = preferencesBox.get(PreferenceKeys.installDate);
      expect(firstWrite, isNotNull);

      await container.read(installDateProvider.notifier).recordIfNeeded();
      expect(preferencesBox.get(PreferenceKeys.installDate), firstWrite);
    },
  );

  // Requested directly: "incorporate dev trigger for restart trial so we
  // can test paywall in apple sandbox account" — this is the mechanism
  // behind that trigger (see developer_settings_screen.dart's own "Reset
  // trial" button), unlike recordIfNeeded above, WRITES OVER an existing
  // timestamp.
  test(
    'InstallDate.reset rewrites installDate to now, restarting the trial '
    'even when one was already recorded',
    () async {
      await setInstallDate(DateTime.now().subtract(const Duration(days: 30)));
      expect(container.read(isInTrialPeriodProvider), isFalse);

      await container.read(installDateProvider.notifier).reset();

      expect(container.read(daysSinceInstallProvider), 0);
      expect(container.read(isInTrialPeriodProvider), isTrue);
      expect(container.read(canCreateTaskProvider), isTrue);
    },
  );
}
