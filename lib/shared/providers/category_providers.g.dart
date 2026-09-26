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

String _$categoryListHash() => r'66479d481edcaada8e9e5ab39eb585572aebfacc';

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

/// [categoryListProvider], minus [BuiltInCategoryIds.general].
///
/// **2026-09-23** — requested directly: General is an invisible
/// "untagged" placeholder — the fallback a task silently carries when no
/// real category was chosen — and must never appear as a selectable
/// option in a tag picker or the Settings tag list. It still exists as a
/// real [Category] row (raw [categoryListProvider] is unfiltered): a
/// task's `categoryId` can resolve to it, [CategoryList.deleteCategory]
/// reassigns orphaned tasks to it, and [CategoryBadge]'s own null-category
/// fallback renders its look directly — none of that changes. This
/// provider exists ONLY for the three UI sites that render "a list of
/// tags to pick/manage" (`task_category_modal.dart`,
/// `task_name_category_modal.dart`, `category_list_screen.dart`), so
/// General is invisible there without needing three separate `.where(...)`
/// calls (and the risk of a future 4th site forgetting the filter).

@ProviderFor(visibleCategoryList)
final visibleCategoryListProvider = VisibleCategoryListProvider._();

/// [categoryListProvider], minus [BuiltInCategoryIds.general].
///
/// **2026-09-23** — requested directly: General is an invisible
/// "untagged" placeholder — the fallback a task silently carries when no
/// real category was chosen — and must never appear as a selectable
/// option in a tag picker or the Settings tag list. It still exists as a
/// real [Category] row (raw [categoryListProvider] is unfiltered): a
/// task's `categoryId` can resolve to it, [CategoryList.deleteCategory]
/// reassigns orphaned tasks to it, and [CategoryBadge]'s own null-category
/// fallback renders its look directly — none of that changes. This
/// provider exists ONLY for the three UI sites that render "a list of
/// tags to pick/manage" (`task_category_modal.dart`,
/// `task_name_category_modal.dart`, `category_list_screen.dart`), so
/// General is invisible there without needing three separate `.where(...)`
/// calls (and the risk of a future 4th site forgetting the filter).

final class VisibleCategoryListProvider
    extends $FunctionalProvider<List<Category>, List<Category>, List<Category>>
    with $Provider<List<Category>> {
  /// [categoryListProvider], minus [BuiltInCategoryIds.general].
  ///
  /// **2026-09-23** — requested directly: General is an invisible
  /// "untagged" placeholder — the fallback a task silently carries when no
  /// real category was chosen — and must never appear as a selectable
  /// option in a tag picker or the Settings tag list. It still exists as a
  /// real [Category] row (raw [categoryListProvider] is unfiltered): a
  /// task's `categoryId` can resolve to it, [CategoryList.deleteCategory]
  /// reassigns orphaned tasks to it, and [CategoryBadge]'s own null-category
  /// fallback renders its look directly — none of that changes. This
  /// provider exists ONLY for the three UI sites that render "a list of
  /// tags to pick/manage" (`task_category_modal.dart`,
  /// `task_name_category_modal.dart`, `category_list_screen.dart`), so
  /// General is invisible there without needing three separate `.where(...)`
  /// calls (and the risk of a future 4th site forgetting the filter).
  VisibleCategoryListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleCategoryListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleCategoryListHash();

  @$internal
  @override
  $ProviderElement<List<Category>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Category> create(Ref ref) {
    return visibleCategoryList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Category> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Category>>(value),
    );
  }
}

String _$visibleCategoryListHash() =>
    r'bb30f45229159943d6d01cba50b5b6158f6cbba1';
