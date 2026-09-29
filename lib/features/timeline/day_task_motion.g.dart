// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_task_motion.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks the Day's tasks ABOVE the widgets that show them. Switching
/// between timeline and list view remounts every task, so "is this task
/// new" can't live in the task widgets (an entrance on mount replayed on
/// every switch — see `_DraggableTaskBlock`). A task arrives or leaves only
/// when the day's own list changes, however it happened (created,
/// scheduled here, deleted, moved away, undone). Changing the day itself
/// never animates. Arrivals are cleared once their frame is built, so a
/// later remount shows them at rest.

@ProviderFor(DayTaskMotion)
final dayTaskMotionProvider = DayTaskMotionProvider._();

/// Tracks the Day's tasks ABOVE the widgets that show them. Switching
/// between timeline and list view remounts every task, so "is this task
/// new" can't live in the task widgets (an entrance on mount replayed on
/// every switch — see `_DraggableTaskBlock`). A task arrives or leaves only
/// when the day's own list changes, however it happened (created,
/// scheduled here, deleted, moved away, undone). Changing the day itself
/// never animates. Arrivals are cleared once their frame is built, so a
/// later remount shows them at rest.
final class DayTaskMotionProvider
    extends $NotifierProvider<DayTaskMotion, DayTaskMotionState> {
  /// Tracks the Day's tasks ABOVE the widgets that show them. Switching
  /// between timeline and list view remounts every task, so "is this task
  /// new" can't live in the task widgets (an entrance on mount replayed on
  /// every switch — see `_DraggableTaskBlock`). A task arrives or leaves only
  /// when the day's own list changes, however it happened (created,
  /// scheduled here, deleted, moved away, undone). Changing the day itself
  /// never animates. Arrivals are cleared once their frame is built, so a
  /// later remount shows them at rest.
  DayTaskMotionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayTaskMotionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayTaskMotionHash();

  @$internal
  @override
  DayTaskMotion create() => DayTaskMotion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayTaskMotionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayTaskMotionState>(value),
    );
  }
}

String _$dayTaskMotionHash() => r'6880a12a8b8de4f1433ab1b57dd0e2ddb66ab2a3';

/// Tracks the Day's tasks ABOVE the widgets that show them. Switching
/// between timeline and list view remounts every task, so "is this task
/// new" can't live in the task widgets (an entrance on mount replayed on
/// every switch — see `_DraggableTaskBlock`). A task arrives or leaves only
/// when the day's own list changes, however it happened (created,
/// scheduled here, deleted, moved away, undone). Changing the day itself
/// never animates. Arrivals are cleared once their frame is built, so a
/// later remount shows them at rest.

abstract class _$DayTaskMotion extends $Notifier<DayTaskMotionState> {
  DayTaskMotionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DayTaskMotionState, DayTaskMotionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DayTaskMotionState, DayTaskMotionState>,
              DayTaskMotionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
