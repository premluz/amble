// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'haptics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [Haptics] implementation.
///
/// A provider rather than a plain `const PlatformHaptics()` at each call
/// site so a widget test can override it with a recording fake — the only
/// way to assert haptic behavior at all, since `flutter test` has no
/// vibration motor and `HapticFeedback`'s platform channel is a no-op
/// there (see docs/DECISIONS.md's own note that device haptics can't be
/// verified off real hardware).
///
/// `keepAlive: true`, matching every other app-level singleton in this
/// codebase: it holds no per-screen state and re-creating it per listener
/// would be pure churn.

@ProviderFor(haptics)
final hapticsProvider = HapticsProvider._();

/// The app's [Haptics] implementation.
///
/// A provider rather than a plain `const PlatformHaptics()` at each call
/// site so a widget test can override it with a recording fake — the only
/// way to assert haptic behavior at all, since `flutter test` has no
/// vibration motor and `HapticFeedback`'s platform channel is a no-op
/// there (see docs/DECISIONS.md's own note that device haptics can't be
/// verified off real hardware).
///
/// `keepAlive: true`, matching every other app-level singleton in this
/// codebase: it holds no per-screen state and re-creating it per listener
/// would be pure churn.

final class HapticsProvider
    extends $FunctionalProvider<Haptics, Haptics, Haptics>
    with $Provider<Haptics> {
  /// The app's [Haptics] implementation.
  ///
  /// A provider rather than a plain `const PlatformHaptics()` at each call
  /// site so a widget test can override it with a recording fake — the only
  /// way to assert haptic behavior at all, since `flutter test` has no
  /// vibration motor and `HapticFeedback`'s platform channel is a no-op
  /// there (see docs/DECISIONS.md's own note that device haptics can't be
  /// verified off real hardware).
  ///
  /// `keepAlive: true`, matching every other app-level singleton in this
  /// codebase: it holds no per-screen state and re-creating it per listener
  /// would be pure churn.
  HapticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hapticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hapticsHash();

  @$internal
  @override
  $ProviderElement<Haptics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Haptics create(Ref ref) {
    return haptics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Haptics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Haptics>(value),
    );
  }
}

String _$hapticsHash() => r'3edd891a23b08d86c5a3622336baf2cc9c328238';
