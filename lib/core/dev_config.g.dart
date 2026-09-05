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
    r'48e37d1f81966e8e998b9b9603fbde915149c2c4';

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
    r'cb3f62d83c085f7ebcc891df88253d5d2b41ebfe';

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
    r'de2c1e94e29671ff14ce3b08e06b7f899eacd592';

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

/// Vertical timeline scale — pixels per minute — for the Spatial Task
/// View. Requested directly as a scratch config so the right value can be
/// dialed in live, separate from the Zone view's own scale below: at the
/// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
/// container barely fit its own header, let alone a task row, which is
/// what caused the reported "missing gap between adjacent zones" (the
/// container was forced to grow past its gap-shrunk floor on nearly every
/// zone, not just unusually packed ones).

@ProviderFor(DevTaskViewPixelsPerMinute)
final devTaskViewPixelsPerMinuteProvider =
    DevTaskViewPixelsPerMinuteProvider._();

/// Vertical timeline scale — pixels per minute — for the Spatial Task
/// View. Requested directly as a scratch config so the right value can be
/// dialed in live, separate from the Zone view's own scale below: at the
/// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
/// container barely fit its own header, let alone a task row, which is
/// what caused the reported "missing gap between adjacent zones" (the
/// container was forced to grow past its gap-shrunk floor on nearly every
/// zone, not just unusually packed ones).
final class DevTaskViewPixelsPerMinuteProvider
    extends $NotifierProvider<DevTaskViewPixelsPerMinute, double> {
  /// Vertical timeline scale — pixels per minute — for the Spatial Task
  /// View. Requested directly as a scratch config so the right value can be
  /// dialed in live, separate from the Zone view's own scale below: at the
  /// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
  /// container barely fit its own header, let alone a task row, which is
  /// what caused the reported "missing gap between adjacent zones" (the
  /// container was forced to grow past its gap-shrunk floor on nearly every
  /// zone, not just unusually packed ones).
  DevTaskViewPixelsPerMinuteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTaskViewPixelsPerMinuteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTaskViewPixelsPerMinuteHash();

  @$internal
  @override
  DevTaskViewPixelsPerMinute create() => DevTaskViewPixelsPerMinute();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$devTaskViewPixelsPerMinuteHash() =>
    r'a87bf724e2657d9726b687607ac425287e474c42';

/// Vertical timeline scale — pixels per minute — for the Spatial Task
/// View. Requested directly as a scratch config so the right value can be
/// dialed in live, separate from the Zone view's own scale below: at the
/// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
/// container barely fit its own header, let alone a task row, which is
/// what caused the reported "missing gap between adjacent zones" (the
/// container was forced to grow past its gap-shrunk floor on nearly every
/// zone, not just unusually packed ones).

abstract class _$DevTaskViewPixelsPerMinute extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Same as [DevTaskViewPixelsPerMinute], for the Spatial Zone View —
/// independently adjustable, not derived from the Task view's own value.
///
/// Previously defaulted to double the Task view's (3.0) — a short (e.g.
/// 30-minute) Zone-view container barely fit its own header, let alone a
/// task row, at 1.5. Default changed to 1.5 anyway (matching the Task
/// view's own) per direct request; the two remain independently
/// adjustable at runtime if that constraint bites again.

@ProviderFor(DevZoneViewPixelsPerMinute)
final devZoneViewPixelsPerMinuteProvider =
    DevZoneViewPixelsPerMinuteProvider._();

/// Same as [DevTaskViewPixelsPerMinute], for the Spatial Zone View —
/// independently adjustable, not derived from the Task view's own value.
///
/// Previously defaulted to double the Task view's (3.0) — a short (e.g.
/// 30-minute) Zone-view container barely fit its own header, let alone a
/// task row, at 1.5. Default changed to 1.5 anyway (matching the Task
/// view's own) per direct request; the two remain independently
/// adjustable at runtime if that constraint bites again.
final class DevZoneViewPixelsPerMinuteProvider
    extends $NotifierProvider<DevZoneViewPixelsPerMinute, double> {
  /// Same as [DevTaskViewPixelsPerMinute], for the Spatial Zone View —
  /// independently adjustable, not derived from the Task view's own value.
  ///
  /// Previously defaulted to double the Task view's (3.0) — a short (e.g.
  /// 30-minute) Zone-view container barely fit its own header, let alone a
  /// task row, at 1.5. Default changed to 1.5 anyway (matching the Task
  /// view's own) per direct request; the two remain independently
  /// adjustable at runtime if that constraint bites again.
  DevZoneViewPixelsPerMinuteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devZoneViewPixelsPerMinuteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devZoneViewPixelsPerMinuteHash();

  @$internal
  @override
  DevZoneViewPixelsPerMinute create() => DevZoneViewPixelsPerMinute();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$devZoneViewPixelsPerMinuteHash() =>
    r'49f716180f59c531c0b1feb8675728ac1bd69888';

/// Same as [DevTaskViewPixelsPerMinute], for the Spatial Zone View —
/// independently adjustable, not derived from the Task view's own value.
///
/// Previously defaulted to double the Task view's (3.0) — a short (e.g.
/// 30-minute) Zone-view container barely fit its own header, let alone a
/// task row, at 1.5. Default changed to 1.5 anyway (matching the Task
/// view's own) per direct request; the two remain independently
/// adjustable at runtime if that constraint bites again.

abstract class _$DevZoneViewPixelsPerMinute extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether `FreeWindowBlock` (the "1h 40m window, add a task" prompt
/// shown for large gaps between tasks on the Task view) renders at all.
/// Requested directly as a scratch on/off toggle.

@ProviderFor(DevShowFreeWindowPrompt)
final devShowFreeWindowPromptProvider = DevShowFreeWindowPromptProvider._();

/// Whether `FreeWindowBlock` (the "1h 40m window, add a task" prompt
/// shown for large gaps between tasks on the Task view) renders at all.
/// Requested directly as a scratch on/off toggle.
final class DevShowFreeWindowPromptProvider
    extends $NotifierProvider<DevShowFreeWindowPrompt, bool> {
  /// Whether `FreeWindowBlock` (the "1h 40m window, add a task" prompt
  /// shown for large gaps between tasks on the Task view) renders at all.
  /// Requested directly as a scratch on/off toggle.
  DevShowFreeWindowPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devShowFreeWindowPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devShowFreeWindowPromptHash();

  @$internal
  @override
  DevShowFreeWindowPrompt create() => DevShowFreeWindowPrompt();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devShowFreeWindowPromptHash() =>
    r'aaaab8b8f17106f74c5d989b26f26fb2de21ff57';

/// Whether `FreeWindowBlock` (the "1h 40m window, add a task" prompt
/// shown for large gaps between tasks on the Task view) renders at all.
/// Requested directly as a scratch on/off toggle.

abstract class _$DevShowFreeWindowPrompt extends $Notifier<bool> {
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

/// Whether Zone view is reachable at all from the Timeline's own
/// view-cycle button. Requested directly as a scratch toggle, default OFF:
/// "that means that switch in timeline goes through task and list view
/// only."
///
/// ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than
/// replacing it (see `day_strip.dart`), so it can only ever REMOVE Zone
/// view from the cycle, never force it on where the feature flag itself
/// says no. Turning it off while Zone view happens to be the active mode
/// also falls back to Task view, rather than stranding the user in a mode
/// the button can no longer cycle out of.

@ProviderFor(DevZoneViewInCycle)
final devZoneViewInCycleProvider = DevZoneViewInCycleProvider._();

/// Whether Zone view is reachable at all from the Timeline's own
/// view-cycle button. Requested directly as a scratch toggle, default OFF:
/// "that means that switch in timeline goes through task and list view
/// only."
///
/// ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than
/// replacing it (see `day_strip.dart`), so it can only ever REMOVE Zone
/// view from the cycle, never force it on where the feature flag itself
/// says no. Turning it off while Zone view happens to be the active mode
/// also falls back to Task view, rather than stranding the user in a mode
/// the button can no longer cycle out of.
final class DevZoneViewInCycleProvider
    extends $NotifierProvider<DevZoneViewInCycle, bool> {
  /// Whether Zone view is reachable at all from the Timeline's own
  /// view-cycle button. Requested directly as a scratch toggle, default OFF:
  /// "that means that switch in timeline goes through task and list view
  /// only."
  ///
  /// ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than
  /// replacing it (see `day_strip.dart`), so it can only ever REMOVE Zone
  /// view from the cycle, never force it on where the feature flag itself
  /// says no. Turning it off while Zone view happens to be the active mode
  /// also falls back to Task view, rather than stranding the user in a mode
  /// the button can no longer cycle out of.
  DevZoneViewInCycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devZoneViewInCycleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devZoneViewInCycleHash();

  @$internal
  @override
  DevZoneViewInCycle create() => DevZoneViewInCycle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devZoneViewInCycleHash() =>
    r'e6ab0e7d3bf37f7a0e267cc7737987834c493c1f';

/// Whether Zone view is reachable at all from the Timeline's own
/// view-cycle button. Requested directly as a scratch toggle, default OFF:
/// "that means that switch in timeline goes through task and list view
/// only."
///
/// ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than
/// replacing it (see `day_strip.dart`), so it can only ever REMOVE Zone
/// view from the cycle, never force it on where the feature flag itself
/// says no. Turning it off while Zone view happens to be the active mode
/// also falls back to Task view, rather than stranding the user in a mode
/// the button can no longer cycle out of.

abstract class _$DevZoneViewInCycle extends $Notifier<bool> {
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
