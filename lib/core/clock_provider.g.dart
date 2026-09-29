// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one source of "now" for day-relative UI (today, the current-time
/// line, scroll-to-now). Tests override it with a fixed instant so a run
/// late in the evening doesn't push fixtures across midnight.

@ProviderFor(now)
final nowProvider = NowProvider._();

/// The one source of "now" for day-relative UI (today, the current-time
/// line, scroll-to-now). Tests override it with a fixed instant so a run
/// late in the evening doesn't push fixtures across midnight.

final class NowProvider extends $FunctionalProvider<Now, Now, Now>
    with $Provider<Now> {
  /// The one source of "now" for day-relative UI (today, the current-time
  /// line, scroll-to-now). Tests override it with a fixed instant so a run
  /// late in the evening doesn't push fixtures across midnight.
  NowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nowHash();

  @$internal
  @override
  $ProviderElement<Now> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Now create(Ref ref) {
    return now(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Now value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Now>(value),
    );
  }
}

String _$nowHash() => r'6d30d9a705746c2c0acb3a1506bd12ce68e5bceb';
