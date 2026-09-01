// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dev_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DevTimelineTaskTextLayout)
final devTimelineTaskTextLayoutProvider = DevTimelineTaskTextLayoutProvider._();

final class DevTimelineTaskTextLayoutProvider
    extends
        $NotifierProvider<DevTimelineTaskTextLayout, TimelineTaskTextLayout> {
  DevTimelineTaskTextLayoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTimelineTaskTextLayoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTimelineTaskTextLayoutHash();

  @$internal
  @override
  DevTimelineTaskTextLayout create() => DevTimelineTaskTextLayout();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimelineTaskTextLayout value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimelineTaskTextLayout>(value),
    );
  }
}

String _$devTimelineTaskTextLayoutHash() =>
    r'63e47152d5d79e1be015fdcde7c3e1b8035a7195';

abstract class _$DevTimelineTaskTextLayout
    extends $Notifier<TimelineTaskTextLayout> {
  TimelineTaskTextLayout build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TimelineTaskTextLayout, TimelineTaskTextLayout>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimelineTaskTextLayout, TimelineTaskTextLayout>,
              TimelineTaskTextLayout,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The bell/repeat/moved/tracked-behavior icon row under a task's
/// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).

@ProviderFor(DevTimelineTaskIconsVisible)
final devTimelineTaskIconsVisibleProvider =
    DevTimelineTaskIconsVisibleProvider._();

/// The bell/repeat/moved/tracked-behavior icon row under a task's
/// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).
final class DevTimelineTaskIconsVisibleProvider
    extends $NotifierProvider<DevTimelineTaskIconsVisible, bool> {
  /// The bell/repeat/moved/tracked-behavior icon row under a task's
  /// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).
  DevTimelineTaskIconsVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTimelineTaskIconsVisibleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTimelineTaskIconsVisibleHash();

  @$internal
  @override
  DevTimelineTaskIconsVisible create() => DevTimelineTaskIconsVisible();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devTimelineTaskIconsVisibleHash() =>
    r'a9a16d06ae249e639a598e75833fb4b3432fb4a3';

/// The bell/repeat/moved/tracked-behavior icon row under a task's
/// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).

abstract class _$DevTimelineTaskIconsVisible extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The `(45m)`-style duration suffix on a task's time line.

@ProviderFor(DevTimelineTaskDurationVisible)
final devTimelineTaskDurationVisibleProvider =
    DevTimelineTaskDurationVisibleProvider._();

/// The `(45m)`-style duration suffix on a task's time line.
final class DevTimelineTaskDurationVisibleProvider
    extends $NotifierProvider<DevTimelineTaskDurationVisible, bool> {
  /// The `(45m)`-style duration suffix on a task's time line.
  DevTimelineTaskDurationVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTimelineTaskDurationVisibleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTimelineTaskDurationVisibleHash();

  @$internal
  @override
  DevTimelineTaskDurationVisible create() => DevTimelineTaskDurationVisible();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devTimelineTaskDurationVisibleHash() =>
    r'1f202714bb5f09f125852ee48c42d06d81c7985a';

/// The `(45m)`-style duration suffix on a task's time line.

abstract class _$DevTimelineTaskDurationVisible extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
