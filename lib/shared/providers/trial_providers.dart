import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:hive_ce_flutter/hive_ce_flutter.dart' show HiveError;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/preferences_repository.dart';
import 'preferences_providers.dart';
import 'purchases_providers.dart';

part 'trial_providers.g.dart';

/// Requested directly: "lock behind 21 day trial ability to add new tasks
/// via any route." The trial clock is one shared `installDate` timestamp
/// (`main.dart` writes it once, on first launch — see
/// `recordInstallDateIfNeeded`); `isPantaProProvider` (already wired for
/// Export/Import's own gate — see `backup_settings_screen.dart`) is the
/// permanent unlock. Both feed [canCreateTaskProvider], the single check
/// `TaskList.createTask`/`captureTask` consult — see that class's own doc
/// comments for why the gate lives there rather than at each of the 4+ UI
/// call sites (quick capture, task detail, quick-create overlay, both
/// native App Intent platforms).
const int trialLengthDays = 21;

/// Thrown by `TaskList.createTask`/`captureTask` when neither the trial
/// nor `panta_pro` covers task creation. Callers with a widget tree catch
/// this and present the paywall (mirroring `backup_settings_screen.dart`'s
/// `_ensureUnlocked`); `AppIntentService` lets it surface as a plain
/// message the OS shows the user, same shape as its own `AppIntentFailure`.
class TrialExpiredException implements Exception {
  const TrialExpiredException();

  static const String message =
      'Your free trial has ended. Upgrade to Panta Pro to keep adding tasks.';

  @override
  String toString() => message;
}

/// Writes [PreferenceKeys.installDate] once, on this install's first
/// launch. Called from `main.dart` before `runApp`, same "launch-only,
/// idempotent, gated by presence-of-value rather than a separate boolean
/// flag" shape as `TaskFontSizeSetting.migrateIfNeeded`.
@Riverpod(keepAlive: true)
class InstallDate extends _$InstallDate {
  @override
  void build() {}

  Future<void> recordIfNeeded() async {
    final repository = ref.read(preferencesRepositoryProvider);
    if (repository.getValue<String>(PreferenceKeys.installDate) != null) {
      return;
    }
    await repository.setValue(
      PreferenceKeys.installDate,
      DateTime.now().toIso8601String(),
    );
  }

  /// Debug-only: rewrites [PreferenceKeys.installDate] to right now,
  /// restarting the 21-day trial from day zero — added so a RevenueCat
  /// sandbox tester can re-run the whole trial-expiry → paywall flow
  /// without reinstalling the app or clearing app data. Never exposed
  /// outside a `kDebugMode` gate — see the Settings screen's "Developer"
  /// section. Mirrors `HasSeenSplash.reset()`'s own debug-reset shape,
  /// but this notifier's own `state` is `void` (nothing downstream reads
  /// it directly) — `daysSinceInstallProvider` reads the preference value
  /// itself, so an explicit `ref.invalidate` is what actually makes the
  /// change visible, not a `state =` assignment.
  Future<void> reset() async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.installDate, DateTime.now().toIso8601String());
    ref.invalidate(daysSinceInstallProvider);
  }
}

/// Days elapsed since [PreferenceKeys.installDate] was recorded, or 0 if
/// it hasn't been written yet (should only happen for the brief window
/// before `main.dart`'s launch-time write completes — never once the app
/// is actually running). Treating "not recorded yet" as "day zero" rather
/// than "trial over" errs toward not locking out a fresh install on a
/// technicality.
///
/// Also returns 0 if [preferencesRepositoryProvider] itself throws
/// [HiveError] (its box was never opened) — every widget test that
/// exercises `TaskList.createTask`/`captureTask` without deliberately
/// testing the trial gate now transitively depends on this provider (it
/// didn't before), and the overwhelming majority of them have no reason
/// to know or care about a `preferences` box. Confirmed via
/// AskUserQuestion: degrade to "trial active" rather than requiring every
/// one of those ~100 pre-existing test files to add an override for a
/// feature they aren't testing — same "unconfigured means don't block"
/// posture `RevenueCatConfig.isAvailable` already takes for purchases.
@riverpod
int daysSinceInstall(Ref ref) {
  final String? installDateStr;
  try {
    installDateStr = ref
        .watch(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.installDate);
  } on ProviderException catch (error) {
    // Riverpod wraps the box's own thrown HiveError in a ProviderException
    // when a dependency provider (preferencesRepositoryProvider here) is
    // in error state — the real HiveError never surfaces directly to this
    // watch call. Only swallow THAT specific cause; a genuinely different
    // failure re-throws rather than silently degrading.
    if (error.exception is HiveError) return 0;
    rethrow;
  }
  if (installDateStr == null) return 0;
  final installDate = DateTime.parse(installDateStr);
  return DateTime.now().difference(installDate).inDays;
}

/// Whether the 21-day free trial is still active for THIS install —
/// independent of `panta_pro`; see [canCreateTaskProvider] for the
/// combined check callers actually want.
@riverpod
bool isInTrialPeriod(Ref ref) {
  return ref.watch(daysSinceInstallProvider) < trialLengthDays;
}

/// Whole days left in the trial, floored at 0 once it's expired — for
/// surfacing a "N days left" countdown in Settings. Not currently wired
/// into any screen; added alongside the gate so a future countdown UI
/// doesn't need its own date math.
@riverpod
int daysRemainingInTrial(Ref ref) {
  final int remaining = trialLengthDays - ref.watch(daysSinceInstallProvider);
  return remaining > 0 ? remaining : 0;
}

/// Whether new tasks can be created right now: in trial OR `panta_pro` is
/// active. This — not [isInTrialPeriod] alone — is what
/// `TaskList.createTask`/`captureTask` check. Once `panta_pro` becomes
/// active this returns true permanently regardless of trial state, same
/// "OR" shape the Export/Import gate uses.
@riverpod
bool canCreateTask(Ref ref) {
  if (ref.watch(isInTrialPeriodProvider)) return true;
  return ref.watch(isPantaProProvider);
}
