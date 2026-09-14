// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(zoneRepository)
final zoneRepositoryProvider = ZoneRepositoryProvider._();

final class ZoneRepositoryProvider
    extends $FunctionalProvider<ZoneRepository, ZoneRepository, ZoneRepository>
    with $Provider<ZoneRepository> {
  ZoneRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneRepositoryHash();

  @$internal
  @override
  $ProviderElement<ZoneRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ZoneRepository create(Ref ref) {
    return zoneRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ZoneRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ZoneRepository>(value),
    );
  }
}

String _$zoneRepositoryHash() => r'c8a7f7a9e2af5dacc8433e092836ed23c61340a2';

/// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — no Zone UI exists and none is gated
/// yet (see `core/feature_flags.dart`). Built now so the data layer is
/// complete and testable ahead of that UI.

@ProviderFor(ZoneList)
final zoneListProvider = ZoneListProvider._();

/// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — no Zone UI exists and none is gated
/// yet (see `core/feature_flags.dart`). Built now so the data layer is
/// complete and testable ahead of that UI.
final class ZoneListProvider extends $NotifierProvider<ZoneList, List<Zone>> {
  /// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
  ///
  /// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
  /// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
  /// caused a real bug where a notifier's own write could be torn down
  /// mid-flight with no listener active. Same reasoning applies here.
  ///
  /// Nothing reads this provider yet — no Zone UI exists and none is gated
  /// yet (see `core/feature_flags.dart`). Built now so the data layer is
  /// complete and testable ahead of that UI.
  ZoneListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneListHash();

  @$internal
  @override
  ZoneList create() => ZoneList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Zone> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Zone>>(value),
    );
  }
}

String _$zoneListHash() => r'ad79c7a77a8a0e00ef00370e700ab3aa4398fc3e';

/// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — no Zone UI exists and none is gated
/// yet (see `core/feature_flags.dart`). Built now so the data layer is
/// complete and testable ahead of that UI.

abstract class _$ZoneList extends $Notifier<List<Zone>> {
  List<Zone> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Zone>, List<Zone>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Zone>, List<Zone>>,
              List<Zone>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
