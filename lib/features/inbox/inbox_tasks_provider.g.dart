// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.

@ProviderFor(inboxTasks)
final inboxTasksProvider = InboxTasksProvider._();

/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.

final class InboxTasksProvider
    extends $FunctionalProvider<List<Task>, List<Task>, List<Task>>
    with $Provider<List<Task>> {
  /// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
  /// from [taskListProvider] (Phase 1), reactive with no manual refresh.
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

String _$inboxTasksHash() => r'14da40fdee3be8a093194ef9ad1e9c1849d3a2bd';
