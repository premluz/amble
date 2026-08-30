// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_behavior_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trackedBehaviorRepository)
final trackedBehaviorRepositoryProvider = TrackedBehaviorRepositoryProvider._();

final class TrackedBehaviorRepositoryProvider
    extends
        $FunctionalProvider<
          TrackedBehaviorRepository,
          TrackedBehaviorRepository,
          TrackedBehaviorRepository
        >
    with $Provider<TrackedBehaviorRepository> {
  TrackedBehaviorRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackedBehaviorRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackedBehaviorRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrackedBehaviorRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrackedBehaviorRepository create(Ref ref) {
    return trackedBehaviorRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackedBehaviorRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackedBehaviorRepository>(value),
    );
  }
}

String _$trackedBehaviorRepositoryHash() =>
    r'03741e0058931b579cf55d27143deeda30c6772b';

/// CRUD state over [TrackedBehaviorRepository], mirroring [TaskList].
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — the TrackedBehavior UI doesn't exist
/// and is gated behind [FeatureFlags.trackedBehaviorEnabled]. It's built
/// now so the data layer is complete and testable ahead of that UI.

@ProviderFor(TrackedBehaviorList)
final trackedBehaviorListProvider = TrackedBehaviorListProvider._();

/// CRUD state over [TrackedBehaviorRepository], mirroring [TaskList].
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — the TrackedBehavior UI doesn't exist
/// and is gated behind [FeatureFlags.trackedBehaviorEnabled]. It's built
/// now so the data layer is complete and testable ahead of that UI.
final class TrackedBehaviorListProvider
    extends $NotifierProvider<TrackedBehaviorList, List<TrackedBehavior>> {
  /// CRUD state over [TrackedBehaviorRepository], mirroring [TaskList].
  ///
  /// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
  /// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
  /// caused a real bug where a notifier's own write could be torn down
  /// mid-flight with no listener active. Same reasoning applies here.
  ///
  /// Nothing reads this provider yet — the TrackedBehavior UI doesn't exist
  /// and is gated behind [FeatureFlags.trackedBehaviorEnabled]. It's built
  /// now so the data layer is complete and testable ahead of that UI.
  TrackedBehaviorListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackedBehaviorListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackedBehaviorListHash();

  @$internal
  @override
  TrackedBehaviorList create() => TrackedBehaviorList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TrackedBehavior> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TrackedBehavior>>(value),
    );
  }
}

String _$trackedBehaviorListHash() =>
    r'868670e11b1084cee528bde2dd46f1fe0b84decf';

/// CRUD state over [TrackedBehaviorRepository], mirroring [TaskList].
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — the TrackedBehavior UI doesn't exist
/// and is gated behind [FeatureFlags.trackedBehaviorEnabled]. It's built
/// now so the data layer is complete and testable ahead of that UI.

abstract class _$TrackedBehaviorList extends $Notifier<List<TrackedBehavior>> {
  List<TrackedBehavior> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<TrackedBehavior>, List<TrackedBehavior>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TrackedBehavior>, List<TrackedBehavior>>,
              List<TrackedBehavior>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
