// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_template_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskTemplateRepository)
final taskTemplateRepositoryProvider = TaskTemplateRepositoryProvider._();

final class TaskTemplateRepositoryProvider
    extends
        $FunctionalProvider<
          TaskTemplateRepository,
          TaskTemplateRepository,
          TaskTemplateRepository
        >
    with $Provider<TaskTemplateRepository> {
  TaskTemplateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskTemplateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskTemplateRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskTemplateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaskTemplateRepository create(Ref ref) {
    return taskTemplateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskTemplateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskTemplateRepository>(value),
    );
  }
}

String _$taskTemplateRepositoryHash() =>
    r'1bf67ff16f1620d43724379c6d01f626446aabaa';

/// CRUD state over [TaskTemplateRepository], mirroring [ZoneList]'s shape —
/// the closest existing precedent, since both entities support the full
/// create/list/edit/delete set (unlike [CategoryList], which is create-only).
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md: this is
/// session-scoped app state read by the Inbox's Templates tab, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight with no listener active.
///
/// Every write to a template goes through here — no feature code touches
/// [TaskTemplateRepository] or Hive directly.

@ProviderFor(TaskTemplateList)
final taskTemplateListProvider = TaskTemplateListProvider._();

/// CRUD state over [TaskTemplateRepository], mirroring [ZoneList]'s shape —
/// the closest existing precedent, since both entities support the full
/// create/list/edit/delete set (unlike [CategoryList], which is create-only).
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md: this is
/// session-scoped app state read by the Inbox's Templates tab, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight with no listener active.
///
/// Every write to a template goes through here — no feature code touches
/// [TaskTemplateRepository] or Hive directly.
final class TaskTemplateListProvider
    extends $NotifierProvider<TaskTemplateList, List<TaskTemplate>> {
  /// CRUD state over [TaskTemplateRepository], mirroring [ZoneList]'s shape —
  /// the closest existing precedent, since both entities support the full
  /// create/list/edit/delete set (unlike [CategoryList], which is create-only).
  ///
  /// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md: this is
  /// session-scoped app state read by the Inbox's Templates tab, and
  /// `autoDispose` caused a real bug where a notifier's own write could be
  /// torn down mid-flight with no listener active.
  ///
  /// Every write to a template goes through here — no feature code touches
  /// [TaskTemplateRepository] or Hive directly.
  TaskTemplateListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskTemplateListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskTemplateListHash();

  @$internal
  @override
  TaskTemplateList create() => TaskTemplateList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TaskTemplate> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TaskTemplate>>(value),
    );
  }
}

String _$taskTemplateListHash() => r'5bc69220328d704308c5a7a40ded5aa672142c13';

/// CRUD state over [TaskTemplateRepository], mirroring [ZoneList]'s shape —
/// the closest existing precedent, since both entities support the full
/// create/list/edit/delete set (unlike [CategoryList], which is create-only).
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md: this is
/// session-scoped app state read by the Inbox's Templates tab, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight with no listener active.
///
/// Every write to a template goes through here — no feature code touches
/// [TaskTemplateRepository] or Hive directly.

abstract class _$TaskTemplateList extends $Notifier<List<TaskTemplate>> {
  List<TaskTemplate> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<TaskTemplate>, List<TaskTemplate>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TaskTemplate>, List<TaskTemplate>>,
              List<TaskTemplate>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
