// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trial_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Writes [PreferenceKeys.installDate] once, on this install's first
/// launch. Called from `main.dart` before `runApp`, same "launch-only,
/// idempotent, gated by presence-of-value rather than a separate boolean
/// flag" shape as `TaskFontSizeSetting.migrateIfNeeded`.

@ProviderFor(InstallDate)
final installDateProvider = InstallDateProvider._();

/// Writes [PreferenceKeys.installDate] once, on this install's first
/// launch. Called from `main.dart` before `runApp`, same "launch-only,
/// idempotent, gated by presence-of-value rather than a separate boolean
/// flag" shape as `TaskFontSizeSetting.migrateIfNeeded`.
final class InstallDateProvider extends $NotifierProvider<InstallDate, void> {
  /// Writes [PreferenceKeys.installDate] once, on this install's first
  /// launch. Called from `main.dart` before `runApp`, same "launch-only,
  /// idempotent, gated by presence-of-value rather than a separate boolean
  /// flag" shape as `TaskFontSizeSetting.migrateIfNeeded`.
  InstallDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installDateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installDateHash();

  @$internal
  @override
  InstallDate create() => InstallDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$installDateHash() => r'11d29e6068468b6106104d16fab8b33349b7e18d';

/// Writes [PreferenceKeys.installDate] once, on this install's first
/// launch. Called from `main.dart` before `runApp`, same "launch-only,
/// idempotent, gated by presence-of-value rather than a separate boolean
/// flag" shape as `TaskFontSizeSetting.migrateIfNeeded`.

abstract class _$InstallDate extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Days elapsed since [PreferenceKeys.installDate] was recorded, or 0 if
/// it hasn't been written yet (should only happen for the brief window
/// before `main.dart`'s launch-time write completes — never once the app
/// is actually running). Treating "not recorded yet" as "day zero" rather
/// than "trial over" errs toward not locking out a fresh install on a
/// technicality.

@ProviderFor(daysSinceInstall)
final daysSinceInstallProvider = DaysSinceInstallProvider._();

/// Days elapsed since [PreferenceKeys.installDate] was recorded, or 0 if
/// it hasn't been written yet (should only happen for the brief window
/// before `main.dart`'s launch-time write completes — never once the app
/// is actually running). Treating "not recorded yet" as "day zero" rather
/// than "trial over" errs toward not locking out a fresh install on a
/// technicality.

final class DaysSinceInstallProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Days elapsed since [PreferenceKeys.installDate] was recorded, or 0 if
  /// it hasn't been written yet (should only happen for the brief window
  /// before `main.dart`'s launch-time write completes — never once the app
  /// is actually running). Treating "not recorded yet" as "day zero" rather
  /// than "trial over" errs toward not locking out a fresh install on a
  /// technicality.
  DaysSinceInstallProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'daysSinceInstallProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$daysSinceInstallHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return daysSinceInstall(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$daysSinceInstallHash() => r'3d78050f20191429c6c51e9a07114071f8212ae9';

/// Whether the 21-day free trial is still active for THIS install —
/// independent of `panta_pro`; see [canCreateTaskProvider] for the
/// combined check callers actually want.

@ProviderFor(isInTrialPeriod)
final isInTrialPeriodProvider = IsInTrialPeriodProvider._();

/// Whether the 21-day free trial is still active for THIS install —
/// independent of `panta_pro`; see [canCreateTaskProvider] for the
/// combined check callers actually want.

final class IsInTrialPeriodProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the 21-day free trial is still active for THIS install —
  /// independent of `panta_pro`; see [canCreateTaskProvider] for the
  /// combined check callers actually want.
  IsInTrialPeriodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isInTrialPeriodProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isInTrialPeriodHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isInTrialPeriod(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isInTrialPeriodHash() => r'ce3f01748b390723923f446cfcbbabb1512d6e3a';

/// Whole days left in the trial, floored at 0 once it's expired — for
/// surfacing a "N days left" countdown in Settings. Not currently wired
/// into any screen; added alongside the gate so a future countdown UI
/// doesn't need its own date math.

@ProviderFor(daysRemainingInTrial)
final daysRemainingInTrialProvider = DaysRemainingInTrialProvider._();

/// Whole days left in the trial, floored at 0 once it's expired — for
/// surfacing a "N days left" countdown in Settings. Not currently wired
/// into any screen; added alongside the gate so a future countdown UI
/// doesn't need its own date math.

final class DaysRemainingInTrialProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Whole days left in the trial, floored at 0 once it's expired — for
  /// surfacing a "N days left" countdown in Settings. Not currently wired
  /// into any screen; added alongside the gate so a future countdown UI
  /// doesn't need its own date math.
  DaysRemainingInTrialProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'daysRemainingInTrialProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$daysRemainingInTrialHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return daysRemainingInTrial(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$daysRemainingInTrialHash() =>
    r'4097d315b73e8de8d0b9050a1bc60e855740e316';

/// Whether new tasks can be created right now: in trial OR `panta_pro` is
/// active. This — not [isInTrialPeriod] alone — is what
/// `TaskList.createTask`/`captureTask` check. Once `panta_pro` becomes
/// active this returns true permanently regardless of trial state, same
/// "OR" shape the Export/Import gate uses.

@ProviderFor(canCreateTask)
final canCreateTaskProvider = CanCreateTaskProvider._();

/// Whether new tasks can be created right now: in trial OR `panta_pro` is
/// active. This — not [isInTrialPeriod] alone — is what
/// `TaskList.createTask`/`captureTask` check. Once `panta_pro` becomes
/// active this returns true permanently regardless of trial state, same
/// "OR" shape the Export/Import gate uses.

final class CanCreateTaskProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether new tasks can be created right now: in trial OR `panta_pro` is
  /// active. This — not [isInTrialPeriod] alone — is what
  /// `TaskList.createTask`/`captureTask` check. Once `panta_pro` becomes
  /// active this returns true permanently regardless of trial state, same
  /// "OR" shape the Export/Import gate uses.
  CanCreateTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canCreateTaskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canCreateTaskHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return canCreateTask(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$canCreateTaskHash() => r'02aaa6925b47b594fa5d788f80467d2106c4de47';
