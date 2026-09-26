// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sectionRepository)
final sectionRepositoryProvider = SectionRepositoryProvider._();

final class SectionRepositoryProvider
    extends
        $FunctionalProvider<
          SectionRepository,
          SectionRepository,
          SectionRepository
        >
    with $Provider<SectionRepository> {
  SectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<SectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SectionRepository create(Ref ref) {
    return sectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SectionRepository>(value),
    );
  }
}

String _$sectionRepositoryHash() => r'ff985c670ddbc0226c1087397026452d613682c3';

/// CRUD state over [SectionRepository], mirroring [CategoryList]'s shape.
///
/// `keepAlive: true` — same reasoning as [CategoryList]: session-scoped
/// app state read by both the Inbox's own tab row and its create-section
/// prompt, not screen-scoped state.
///
/// No seeded/built-in rows — unlike [CategoryList], every [Section] is
/// user-created (requested directly), so there is no equivalent of
/// [BuiltInCategoryIds] or a seed/backfill step to run at launch.

@ProviderFor(SectionList)
final sectionListProvider = SectionListProvider._();

/// CRUD state over [SectionRepository], mirroring [CategoryList]'s shape.
///
/// `keepAlive: true` — same reasoning as [CategoryList]: session-scoped
/// app state read by both the Inbox's own tab row and its create-section
/// prompt, not screen-scoped state.
///
/// No seeded/built-in rows — unlike [CategoryList], every [Section] is
/// user-created (requested directly), so there is no equivalent of
/// [BuiltInCategoryIds] or a seed/backfill step to run at launch.
final class SectionListProvider
    extends $NotifierProvider<SectionList, List<Section>> {
  /// CRUD state over [SectionRepository], mirroring [CategoryList]'s shape.
  ///
  /// `keepAlive: true` — same reasoning as [CategoryList]: session-scoped
  /// app state read by both the Inbox's own tab row and its create-section
  /// prompt, not screen-scoped state.
  ///
  /// No seeded/built-in rows — unlike [CategoryList], every [Section] is
  /// user-created (requested directly), so there is no equivalent of
  /// [BuiltInCategoryIds] or a seed/backfill step to run at launch.
  SectionListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sectionListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sectionListHash();

  @$internal
  @override
  SectionList create() => SectionList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Section> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Section>>(value),
    );
  }
}

String _$sectionListHash() => r'b87d5b5d418ae653b9049b3dfb070fb81127cdf6';

/// CRUD state over [SectionRepository], mirroring [CategoryList]'s shape.
///
/// `keepAlive: true` — same reasoning as [CategoryList]: session-scoped
/// app state read by both the Inbox's own tab row and its create-section
/// prompt, not screen-scoped state.
///
/// No seeded/built-in rows — unlike [CategoryList], every [Section] is
/// user-created (requested directly), so there is no equivalent of
/// [BuiltInCategoryIds] or a seed/backfill step to run at launch.

abstract class _$SectionList extends $Notifier<List<Section>> {
  List<Section> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Section>, List<Section>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Section>, List<Section>>,
              List<Section>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
