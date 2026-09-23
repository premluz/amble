// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.
///
/// **2026-09-21 — sorted by [Task.createdAt], newest first**, requested
/// directly ("notes in inbox should have created timestamp if not have
/// already... and recent should be on top"). Replaces the previous
/// stand-in (reversing [HiveTaskRepository.getTasks]'s own Hive
/// insertion order, back when [Task] had no real timestamp field at
/// all) with an explicit sort by the real field — insertion order only
/// ever coincided with creation order by accident, e.g. never after an
/// edit rewrote a row in place. A decorate-sort-undecorate pass, not a
/// bare `List.sort`, since Dart's own `List.sort` is NOT guaranteed
/// stable and two tasks created in the same millisecond (e.g. voice
/// capture's `submit()` looping over several segments) should keep a
/// deterministic relative order across rebuilds.

@ProviderFor(inboxTasks)
final inboxTasksProvider = InboxTasksProvider._();

/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.
///
/// **2026-09-21 — sorted by [Task.createdAt], newest first**, requested
/// directly ("notes in inbox should have created timestamp if not have
/// already... and recent should be on top"). Replaces the previous
/// stand-in (reversing [HiveTaskRepository.getTasks]'s own Hive
/// insertion order, back when [Task] had no real timestamp field at
/// all) with an explicit sort by the real field — insertion order only
/// ever coincided with creation order by accident, e.g. never after an
/// edit rewrote a row in place. A decorate-sort-undecorate pass, not a
/// bare `List.sort`, since Dart's own `List.sort` is NOT guaranteed
/// stable and two tasks created in the same millisecond (e.g. voice
/// capture's `submit()` looping over several segments) should keep a
/// deterministic relative order across rebuilds.

final class InboxTasksProvider
    extends $FunctionalProvider<List<Task>, List<Task>, List<Task>>
    with $Provider<List<Task>> {
  /// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
  /// from [taskListProvider] (Phase 1), reactive with no manual refresh.
  ///
  /// **2026-09-21 — sorted by [Task.createdAt], newest first**, requested
  /// directly ("notes in inbox should have created timestamp if not have
  /// already... and recent should be on top"). Replaces the previous
  /// stand-in (reversing [HiveTaskRepository.getTasks]'s own Hive
  /// insertion order, back when [Task] had no real timestamp field at
  /// all) with an explicit sort by the real field — insertion order only
  /// ever coincided with creation order by accident, e.g. never after an
  /// edit rewrote a row in place. A decorate-sort-undecorate pass, not a
  /// bare `List.sort`, since Dart's own `List.sort` is NOT guaranteed
  /// stable and two tasks created in the same millisecond (e.g. voice
  /// capture's `submit()` looping over several segments) should keep a
  /// deterministic relative order across rebuilds.
  InboxTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxTasksHash();

  @$internal
  @override
  $ProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Task> create(Ref ref) {
    return inboxTasks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Task> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Task>>(value),
    );
  }
}

String _$inboxTasksHash() => r'027ac7ef0fc2ec87da82b6c600a47fd1a006db73';

/// [inboxTasks], narrowed by the Inbox's own Section tab row
/// (`inbox_section_filter_provider.dart`) — "All" (the default) returns
/// [inboxTasks] unchanged, "Unfiled" keeps only tasks with no
/// `Task.sectionId`, and a real Section keeps only tasks filed into it.
/// Client-side filtering over the same small in-memory list every other
/// Inbox derivation already uses, not a second repository query.

@ProviderFor(filteredInboxTasks)
final filteredInboxTasksProvider = FilteredInboxTasksProvider._();

/// [inboxTasks], narrowed by the Inbox's own Section tab row
/// (`inbox_section_filter_provider.dart`) — "All" (the default) returns
/// [inboxTasks] unchanged, "Unfiled" keeps only tasks with no
/// `Task.sectionId`, and a real Section keeps only tasks filed into it.
/// Client-side filtering over the same small in-memory list every other
/// Inbox derivation already uses, not a second repository query.

final class FilteredInboxTasksProvider
    extends $FunctionalProvider<List<Task>, List<Task>, List<Task>>
    with $Provider<List<Task>> {
  /// [inboxTasks], narrowed by the Inbox's own Section tab row
  /// (`inbox_section_filter_provider.dart`) — "All" (the default) returns
  /// [inboxTasks] unchanged, "Unfiled" keeps only tasks with no
  /// `Task.sectionId`, and a real Section keeps only tasks filed into it.
  /// Client-side filtering over the same small in-memory list every other
  /// Inbox derivation already uses, not a second repository query.
  FilteredInboxTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredInboxTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredInboxTasksHash();

  @$internal
  @override
  $ProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Task> create(Ref ref) {
    return filteredInboxTasks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Task> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Task>>(value),
    );
  }
}

String _$filteredInboxTasksHash() =>
    r'94cb4e1265db63f6bb08d339408d9c8b498c490d';
