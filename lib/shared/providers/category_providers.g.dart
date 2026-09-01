// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          CategoryRepository,
          CategoryRepository,
          CategoryRepository
        >
    with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'85b18089c02096239efbb95a0ad73fcdc5f2a6d2';

/// CRUD state over [CategoryRepository], mirroring [TaskList]/
/// [TrackedBehaviorList]'s shape.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by both category-picker sheets, not
/// screen-scoped state.
///
/// No `deleteCategory` — v1 scope is create + list only, per the confirmed
/// decision recorded in docs/DECISIONS.md.

@ProviderFor(CategoryList)
final categoryListProvider = CategoryListProvider._();

/// CRUD state over [CategoryRepository], mirroring [TaskList]/
/// [TrackedBehaviorList]'s shape.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by both category-picker sheets, not
/// screen-scoped state.
///
/// No `deleteCategory` — v1 scope is create + list only, per the confirmed
/// decision recorded in docs/DECISIONS.md.
final class CategoryListProvider
    extends $NotifierProvider<CategoryList, List<Category>> {
  /// CRUD state over [CategoryRepository], mirroring [TaskList]/
  /// [TrackedBehaviorList]'s shape.
  ///
  /// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
  /// is session-scoped app state read by both category-picker sheets, not
  /// screen-scoped state.
  ///
  /// No `deleteCategory` — v1 scope is create + list only, per the confirmed
  /// decision recorded in docs/DECISIONS.md.
  CategoryListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryListHash();

  @$internal
  @override
  CategoryList create() => CategoryList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Category> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Category>>(value),
    );
  }
}

String _$categoryListHash() => r'9cdcd0da546834d539a67fb773643a4139b7bc4d';

/// CRUD state over [CategoryRepository], mirroring [TaskList]/
/// [TrackedBehaviorList]'s shape.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by both category-picker sheets, not
/// screen-scoped state.
///
/// No `deleteCategory` — v1 scope is create + list only, per the confirmed
/// decision recorded in docs/DECISIONS.md.

abstract class _$CategoryList extends $Notifier<List<Category>> {
  List<Category> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Category>, List<Category>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Category>, List<Category>>,
              List<Category>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
