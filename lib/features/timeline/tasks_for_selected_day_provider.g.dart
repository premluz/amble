// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_for_selected_day_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tasks scheduled on [selectedDateProvider]'s day, sorted by time. Derived
/// from [taskListProvider] (Phase 1) — reactive to both the underlying task
/// list and day navigation with no manual refresh.

@ProviderFor(tasksForSelectedDay)
final tasksForSelectedDayProvider = TasksForSelectedDayProvider._();

/// Tasks scheduled on [selectedDateProvider]'s day, sorted by time. Derived
/// from [taskListProvider] (Phase 1) — reactive to both the underlying task
/// list and day navigation with no manual refresh.

final class TasksForSelectedDayProvider
    extends $FunctionalProvider<List<Task>, List<Task>, List<Task>>
    with $Provider<List<Task>> {
  /// Tasks scheduled on [selectedDateProvider]'s day, sorted by time. Derived
  /// from [taskListProvider] (Phase 1) — reactive to both the underlying task
  /// list and day navigation with no manual refresh.
  TasksForSelectedDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksForSelectedDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksForSelectedDayHash();

  @$internal
  @override
  $ProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Task> create(Ref ref) {
    return tasksForSelectedDay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Task> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Task>>(value),
    );
  }
}

String _$tasksForSelectedDayHash() =>
    r'8dc40ea665192e4a0815cb2acac7fc88fd4ae467';
