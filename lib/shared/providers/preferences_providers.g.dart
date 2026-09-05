// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(preferencesRepository)
final preferencesRepositoryProvider = PreferencesRepositoryProvider._();

final class PreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          PreferencesRepository,
          PreferencesRepository,
          PreferencesRepository
        >
    with $Provider<PreferencesRepository> {
  PreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreferencesRepository create(Ref ref) {
    return preferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesRepository>(value),
    );
  }
}

String _$preferencesRepositoryHash() =>
    r'6df2f1c43f65659782a79832aee4f81dc7bf2e3f';

/// The app's theme mode, persisted across launches.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by the root `MaterialApp`, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight. Same reasoning applies here, and more strongly:
/// the root widget is the only listener, so a screen-scoped provider would
/// be wrong by construction.
///
/// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
/// install follows the OS rather than picking a side.

@ProviderFor(ThemeModeSetting)
final themeModeSettingProvider = ThemeModeSettingProvider._();

/// The app's theme mode, persisted across launches.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by the root `MaterialApp`, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight. Same reasoning applies here, and more strongly:
/// the root widget is the only listener, so a screen-scoped provider would
/// be wrong by construction.
///
/// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
/// install follows the OS rather than picking a side.
final class ThemeModeSettingProvider
    extends $NotifierProvider<ThemeModeSetting, AppThemeMode> {
  /// The app's theme mode, persisted across launches.
  ///
  /// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
  /// is session-scoped app state read by the root `MaterialApp`, and
  /// `autoDispose` caused a real bug where a notifier's own write could be
  /// torn down mid-flight. Same reasoning applies here, and more strongly:
  /// the root widget is the only listener, so a screen-scoped provider would
  /// be wrong by construction.
  ///
  /// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
  /// install follows the OS rather than picking a side.
  ThemeModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeSettingHash() => r'de07321de6503c158f7d0e951e5a581cec0577a6';

/// The app's theme mode, persisted across launches.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by the root `MaterialApp`, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight. Same reasoning applies here, and more strongly:
/// the root widget is the only listener, so a screen-scoped provider would
/// be wrong by construction.
///
/// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
/// install follows the OS rather than picking a side.

abstract class _$ThemeModeSetting extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the first-launch splash/carousel has already been shown.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
/// read once by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state. Defaults to `false` (unseen) when nothing is
/// stored, i.e. every fresh install.

@ProviderFor(HasSeenSplash)
final hasSeenSplashProvider = HasSeenSplashProvider._();

/// Whether the first-launch splash/carousel has already been shown.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
/// read once by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state. Defaults to `false` (unseen) when nothing is
/// stored, i.e. every fresh install.
final class HasSeenSplashProvider
    extends $NotifierProvider<HasSeenSplash, bool> {
  /// Whether the first-launch splash/carousel has already been shown.
  ///
  /// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
  /// read once by the root `MaterialApp` to decide its `home:`, not
  /// screen-scoped state. Defaults to `false` (unseen) when nothing is
  /// stored, i.e. every fresh install.
  HasSeenSplashProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasSeenSplashProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasSeenSplashHash();

  @$internal
  @override
  HasSeenSplash create() => HasSeenSplash();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasSeenSplashHash() => r'4b311db801cd61c387f6a75bcefac32f87cbb132';

/// Whether the first-launch splash/carousel has already been shown.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
/// read once by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state. Defaults to `false` (unseen) when nothing is
/// stored, i.e. every fresh install.

abstract class _$HasSeenSplash extends $Notifier<bool> {
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

/// Whether creating/moving a task into a slot that overlaps an existing task
/// is blocked (reject-and-snap-back) rather than allowed side by side.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting]/
/// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
/// screen-scoped state. Unlike those two, this **defaults to true** when
/// nothing is stored: this is a deliberate, confirmed reversal of the
/// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
/// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
/// added after it) — a fresh install should get the stricter behavior
/// unless the user turns it off.

@ProviderFor(PreventOverlappingTasksSetting)
final preventOverlappingTasksSettingProvider =
    PreventOverlappingTasksSettingProvider._();

/// Whether creating/moving a task into a slot that overlaps an existing task
/// is blocked (reject-and-snap-back) rather than allowed side by side.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting]/
/// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
/// screen-scoped state. Unlike those two, this **defaults to true** when
/// nothing is stored: this is a deliberate, confirmed reversal of the
/// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
/// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
/// added after it) — a fresh install should get the stricter behavior
/// unless the user turns it off.
final class PreventOverlappingTasksSettingProvider
    extends $NotifierProvider<PreventOverlappingTasksSetting, bool> {
  /// Whether creating/moving a task into a slot that overlaps an existing task
  /// is blocked (reject-and-snap-back) rather than allowed side by side.
  ///
  /// `keepAlive: true` for the same reason as [ThemeModeSetting]/
  /// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
  /// screen-scoped state. Unlike those two, this **defaults to true** when
  /// nothing is stored: this is a deliberate, confirmed reversal of the
  /// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
  /// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
  /// added after it) — a fresh install should get the stricter behavior
  /// unless the user turns it off.
  PreventOverlappingTasksSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preventOverlappingTasksSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preventOverlappingTasksSettingHash();

  @$internal
  @override
  PreventOverlappingTasksSetting create() => PreventOverlappingTasksSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$preventOverlappingTasksSettingHash() =>
    r'9f4519669700420a2d8d512d1413ee660a1b0848';

/// Whether creating/moving a task into a slot that overlaps an existing task
/// is blocked (reject-and-snap-back) rather than allowed side by side.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting]/
/// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
/// screen-scoped state. Unlike those two, this **defaults to true** when
/// nothing is stored: this is a deliberate, confirmed reversal of the
/// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
/// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
/// added after it) — a fresh install should get the stricter behavior
/// unless the user turns it off.

abstract class _$PreventOverlappingTasksSetting extends $Notifier<bool> {
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

/// Whether the day view's left-side hour gutter (the grid of clock-hour
/// ticks) is shown.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **true**
/// when nothing is stored, so a fresh install keeps the existing gutter
/// rather than silently hiding it.

@ProviderFor(ShowHourLabelsSetting)
final showHourLabelsSettingProvider = ShowHourLabelsSettingProvider._();

/// Whether the day view's left-side hour gutter (the grid of clock-hour
/// ticks) is shown.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **true**
/// when nothing is stored, so a fresh install keeps the existing gutter
/// rather than silently hiding it.
final class ShowHourLabelsSettingProvider
    extends $NotifierProvider<ShowHourLabelsSetting, bool> {
  /// Whether the day view's left-side hour gutter (the grid of clock-hour
  /// ticks) is shown.
  ///
  /// `keepAlive: true` for the same reason as the other settings above — read
  /// by the Timeline screen, not screen-scoped state. Defaults to **true**
  /// when nothing is stored, so a fresh install keeps the existing gutter
  /// rather than silently hiding it.
  ShowHourLabelsSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showHourLabelsSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showHourLabelsSettingHash();

  @$internal
  @override
  ShowHourLabelsSetting create() => ShowHourLabelsSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showHourLabelsSettingHash() =>
    r'a35ee246b5f3c935db9e1a0dc290f592916c85fd';

/// Whether the day view's left-side hour gutter (the grid of clock-hour
/// ticks) is shown.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **true**
/// when nothing is stored, so a fresh install keeps the existing gutter
/// rather than silently hiding it.

abstract class _$ShowHourLabelsSetting extends $Notifier<bool> {
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

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **true**, matching the connector's existing
/// unconditional-when-`showHourLabels` behavior, so a fresh install is
/// visually unchanged.

@ProviderFor(ShowTimelineConnectorsSetting)
final showTimelineConnectorsSettingProvider =
    ShowTimelineConnectorsSettingProvider._();

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **true**, matching the connector's existing
/// unconditional-when-`showHourLabels` behavior, so a fresh install is
/// visually unchanged.
final class ShowTimelineConnectorsSettingProvider
    extends $NotifierProvider<ShowTimelineConnectorsSetting, bool> {
  /// Whether the gray thread connecting consecutive tasks
  /// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
  /// directly — configurable show/hide, Task view only (Zone view has no
  /// equivalent connector concept, its containers own child layout
  /// directly). Defaults to **true**, matching the connector's existing
  /// unconditional-when-`showHourLabels` behavior, so a fresh install is
  /// visually unchanged.
  ShowTimelineConnectorsSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showTimelineConnectorsSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showTimelineConnectorsSettingHash();

  @$internal
  @override
  ShowTimelineConnectorsSetting create() => ShowTimelineConnectorsSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showTimelineConnectorsSettingHash() =>
    r'0608b838ebf3c1dca510ac4060f9ea841f0dfaba';

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **true**, matching the connector's existing
/// unconditional-when-`showHourLabels` behavior, so a fresh install is
/// visually unchanged.

abstract class _$ShowTimelineConnectorsSetting extends $Notifier<bool> {
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

/// Whether a task's trailing completion checkbox renders at all.
/// Requested directly, and deliberately spanning **all three views** (Task,
/// List, and Zone) from one toggle — unlike
/// [ShowTimelineConnectorsSetting] above, which is Task-view only, since a
/// checkbox that disappeared in one view and not another would read as a
/// bug rather than a setting. Defaults to **true**, matching the
/// checkbox's existing unconditional rendering, so a fresh install is
/// visually unchanged.
///
/// Note: this checkbox is currently the ONLY way to complete a SCHEDULED
/// task — the task detail sheet has no completion control, and the Inbox's
/// own checkbox only covers unscheduled tasks. Turning this off therefore
/// removes the capability, not just the affordance. Shipped as requested,
/// with the Settings copy saying so plainly rather than implying a
/// fallback that doesn't exist.

@ProviderFor(ShowCompletionCheckboxSetting)
final showCompletionCheckboxSettingProvider =
    ShowCompletionCheckboxSettingProvider._();

/// Whether a task's trailing completion checkbox renders at all.
/// Requested directly, and deliberately spanning **all three views** (Task,
/// List, and Zone) from one toggle — unlike
/// [ShowTimelineConnectorsSetting] above, which is Task-view only, since a
/// checkbox that disappeared in one view and not another would read as a
/// bug rather than a setting. Defaults to **true**, matching the
/// checkbox's existing unconditional rendering, so a fresh install is
/// visually unchanged.
///
/// Note: this checkbox is currently the ONLY way to complete a SCHEDULED
/// task — the task detail sheet has no completion control, and the Inbox's
/// own checkbox only covers unscheduled tasks. Turning this off therefore
/// removes the capability, not just the affordance. Shipped as requested,
/// with the Settings copy saying so plainly rather than implying a
/// fallback that doesn't exist.
final class ShowCompletionCheckboxSettingProvider
    extends $NotifierProvider<ShowCompletionCheckboxSetting, bool> {
  /// Whether a task's trailing completion checkbox renders at all.
  /// Requested directly, and deliberately spanning **all three views** (Task,
  /// List, and Zone) from one toggle — unlike
  /// [ShowTimelineConnectorsSetting] above, which is Task-view only, since a
  /// checkbox that disappeared in one view and not another would read as a
  /// bug rather than a setting. Defaults to **true**, matching the
  /// checkbox's existing unconditional rendering, so a fresh install is
  /// visually unchanged.
  ///
  /// Note: this checkbox is currently the ONLY way to complete a SCHEDULED
  /// task — the task detail sheet has no completion control, and the Inbox's
  /// own checkbox only covers unscheduled tasks. Turning this off therefore
  /// removes the capability, not just the affordance. Shipped as requested,
  /// with the Settings copy saying so plainly rather than implying a
  /// fallback that doesn't exist.
  ShowCompletionCheckboxSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showCompletionCheckboxSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showCompletionCheckboxSettingHash();

  @$internal
  @override
  ShowCompletionCheckboxSetting create() => ShowCompletionCheckboxSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showCompletionCheckboxSettingHash() =>
    r'6417aa668f6734e6ac15beb9f1d5387b72a11656';

/// Whether a task's trailing completion checkbox renders at all.
/// Requested directly, and deliberately spanning **all three views** (Task,
/// List, and Zone) from one toggle — unlike
/// [ShowTimelineConnectorsSetting] above, which is Task-view only, since a
/// checkbox that disappeared in one view and not another would read as a
/// bug rather than a setting. Defaults to **true**, matching the
/// checkbox's existing unconditional rendering, so a fresh install is
/// visually unchanged.
///
/// Note: this checkbox is currently the ONLY way to complete a SCHEDULED
/// task — the task detail sheet has no completion control, and the Inbox's
/// own checkbox only covers unscheduled tasks. Turning this off therefore
/// removes the capability, not just the affordance. Shipped as requested,
/// with the Settings copy saying so plainly rather than implying a
/// fallback that doesn't exist.

abstract class _$ShowCompletionCheckboxSetting extends $Notifier<bool> {
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

/// Which rung of the task-size scale (`TaskSize.sm`/`md`/`lg`) the Timeline
/// renders at — one global setting spanning Task view, List view, and Zone
/// view alike, requested directly ("it's not per view, it's a setting,
/// that when set affects all"). `main.dart` reads this to `copyWith` the
/// right `sizeTaskBadge*`/`textTaskTitle*` pair onto the active
/// `AmbleTheme` before it reaches `MaterialApp`, so every existing call
/// site (`TaskCapsuleBlock`, `ZoneContainerBlock`, `OverlapClusterBlock`)
/// picks it up automatically without itself knowing this setting exists.
/// Defaults to `TaskSize.md` — Task view's own prior fixed size, unchanged
/// for a fresh install.

@ProviderFor(TaskSizeSetting)
final taskSizeSettingProvider = TaskSizeSettingProvider._();

/// Which rung of the task-size scale (`TaskSize.sm`/`md`/`lg`) the Timeline
/// renders at — one global setting spanning Task view, List view, and Zone
/// view alike, requested directly ("it's not per view, it's a setting,
/// that when set affects all"). `main.dart` reads this to `copyWith` the
/// right `sizeTaskBadge*`/`textTaskTitle*` pair onto the active
/// `AmbleTheme` before it reaches `MaterialApp`, so every existing call
/// site (`TaskCapsuleBlock`, `ZoneContainerBlock`, `OverlapClusterBlock`)
/// picks it up automatically without itself knowing this setting exists.
/// Defaults to `TaskSize.md` — Task view's own prior fixed size, unchanged
/// for a fresh install.
final class TaskSizeSettingProvider
    extends $NotifierProvider<TaskSizeSetting, TaskSize> {
  /// Which rung of the task-size scale (`TaskSize.sm`/`md`/`lg`) the Timeline
  /// renders at — one global setting spanning Task view, List view, and Zone
  /// view alike, requested directly ("it's not per view, it's a setting,
  /// that when set affects all"). `main.dart` reads this to `copyWith` the
  /// right `sizeTaskBadge*`/`textTaskTitle*` pair onto the active
  /// `AmbleTheme` before it reaches `MaterialApp`, so every existing call
  /// site (`TaskCapsuleBlock`, `ZoneContainerBlock`, `OverlapClusterBlock`)
  /// picks it up automatically without itself knowing this setting exists.
  /// Defaults to `TaskSize.md` — Task view's own prior fixed size, unchanged
  /// for a fresh install.
  TaskSizeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSizeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSizeSettingHash();

  @$internal
  @override
  TaskSizeSetting create() => TaskSizeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSize value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSize>(value),
    );
  }
}

String _$taskSizeSettingHash() => r'fd7df99b5f93119453a73507c3b9138616720d30';

/// Which rung of the task-size scale (`TaskSize.sm`/`md`/`lg`) the Timeline
/// renders at — one global setting spanning Task view, List view, and Zone
/// view alike, requested directly ("it's not per view, it's a setting,
/// that when set affects all"). `main.dart` reads this to `copyWith` the
/// right `sizeTaskBadge*`/`textTaskTitle*` pair onto the active
/// `AmbleTheme` before it reaches `MaterialApp`, so every existing call
/// site (`TaskCapsuleBlock`, `ZoneContainerBlock`, `OverlapClusterBlock`)
/// picks it up automatically without itself knowing this setting exists.
/// Defaults to `TaskSize.md` — Task view's own prior fixed size, unchanged
/// for a fresh install.

abstract class _$TaskSizeSetting extends $Notifier<TaskSize> {
  TaskSize build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TaskSize, TaskSize>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskSize, TaskSize>,
              TaskSize,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the Timeline renders in Zone view — Zones as real layout
/// containers owning their child tasks' positions (see
/// `ZoneContainerBlock`) — instead of the default Task view (where Zones
/// are purely decorative background, see `ZoneBackgroundBlock`).
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced as a Settings toggle when `FeatureFlags.zoneEnabled` is
/// also true — the setting itself has no opinion on the flag; the
/// Settings screen decides visibility.

@ProviderFor(ZoneViewEnabledSetting)
final zoneViewEnabledSettingProvider = ZoneViewEnabledSettingProvider._();

/// Whether the Timeline renders in Zone view — Zones as real layout
/// containers owning their child tasks' positions (see
/// `ZoneContainerBlock`) — instead of the default Task view (where Zones
/// are purely decorative background, see `ZoneBackgroundBlock`).
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced as a Settings toggle when `FeatureFlags.zoneEnabled` is
/// also true — the setting itself has no opinion on the flag; the
/// Settings screen decides visibility.
final class ZoneViewEnabledSettingProvider
    extends $NotifierProvider<ZoneViewEnabledSetting, bool> {
  /// Whether the Timeline renders in Zone view — Zones as real layout
  /// containers owning their child tasks' positions (see
  /// `ZoneContainerBlock`) — instead of the default Task view (where Zones
  /// are purely decorative background, see `ZoneBackgroundBlock`).
  ///
  /// `keepAlive: true` for the same reason as the other settings above.
  /// Defaults to **false** when nothing is stored, so a fresh install (or an
  /// existing one) keeps today's Task view unless the user opts in. Only
  /// ever surfaced as a Settings toggle when `FeatureFlags.zoneEnabled` is
  /// also true — the setting itself has no opinion on the flag; the
  /// Settings screen decides visibility.
  ZoneViewEnabledSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneViewEnabledSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneViewEnabledSettingHash();

  @$internal
  @override
  ZoneViewEnabledSetting create() => ZoneViewEnabledSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$zoneViewEnabledSettingHash() =>
    r'7c3de9f0588b791f6a7c4af625e84f5ef2d5fc81';

/// Whether the Timeline renders in Zone view — Zones as real layout
/// containers owning their child tasks' positions (see
/// `ZoneContainerBlock`) — instead of the default Task view (where Zones
/// are purely decorative background, see `ZoneBackgroundBlock`).
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced as a Settings toggle when `FeatureFlags.zoneEnabled` is
/// also true — the setting itself has no opinion on the flag; the
/// Settings screen decides visibility.

abstract class _$ZoneViewEnabledSetting extends $Notifier<bool> {
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

/// Whether 2–3 mutually-overlapping tasks stay individual capsule blocks
/// (naive spatial overlap) instead of being replaced by one aggregate
/// `OverlapClusterBlock`.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **false**
/// when nothing is stored, i.e. clustering is ON for a fresh install —
/// matches how [PreventOverlappingTasksSetting] defaults to the newer,
/// more-structured behavior rather than requiring an opt-in.

@ProviderFor(DisableOverlapClusteringSetting)
final disableOverlapClusteringSettingProvider =
    DisableOverlapClusteringSettingProvider._();

/// Whether 2–3 mutually-overlapping tasks stay individual capsule blocks
/// (naive spatial overlap) instead of being replaced by one aggregate
/// `OverlapClusterBlock`.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **false**
/// when nothing is stored, i.e. clustering is ON for a fresh install —
/// matches how [PreventOverlappingTasksSetting] defaults to the newer,
/// more-structured behavior rather than requiring an opt-in.
final class DisableOverlapClusteringSettingProvider
    extends $NotifierProvider<DisableOverlapClusteringSetting, bool> {
  /// Whether 2–3 mutually-overlapping tasks stay individual capsule blocks
  /// (naive spatial overlap) instead of being replaced by one aggregate
  /// `OverlapClusterBlock`.
  ///
  /// `keepAlive: true` for the same reason as the other settings above — read
  /// by the Timeline screen, not screen-scoped state. Defaults to **false**
  /// when nothing is stored, i.e. clustering is ON for a fresh install —
  /// matches how [PreventOverlappingTasksSetting] defaults to the newer,
  /// more-structured behavior rather than requiring an opt-in.
  DisableOverlapClusteringSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'disableOverlapClusteringSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$disableOverlapClusteringSettingHash();

  @$internal
  @override
  DisableOverlapClusteringSetting create() => DisableOverlapClusteringSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$disableOverlapClusteringSettingHash() =>
    r'd184876ffadfea6851e6bfe01535f34ee4a223c4';

/// Whether 2–3 mutually-overlapping tasks stay individual capsule blocks
/// (naive spatial overlap) instead of being replaced by one aggregate
/// `OverlapClusterBlock`.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **false**
/// when nothing is stored, i.e. clustering is ON for a fresh install —
/// matches how [PreventOverlappingTasksSetting] defaults to the newer,
/// more-structured behavior rather than requiring an opt-in.

abstract class _$DisableOverlapClusteringSetting extends $Notifier<bool> {
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

/// Which device calendars' events display (read-only) on the Timeline —
/// Feature 1 of CONSTITUTION.md's "Calendar" section, a multi-select
/// SOURCE list distinct from [CalendarSyncTargetIdSetting]'s single
/// DESTINATION calendar.
///
/// `keepAlive: true` for the same reason as the other settings above —
/// read by the Timeline screen, not screen-scoped state. Defaults to an
/// empty list when nothing is stored, so a fresh install (or one where the
/// user has never opened Settings' Calendar section) shows no external
/// events, matching the Timeline's previous calendar-free behavior.

@ProviderFor(CalendarDisplayIdsSetting)
final calendarDisplayIdsSettingProvider = CalendarDisplayIdsSettingProvider._();

/// Which device calendars' events display (read-only) on the Timeline —
/// Feature 1 of CONSTITUTION.md's "Calendar" section, a multi-select
/// SOURCE list distinct from [CalendarSyncTargetIdSetting]'s single
/// DESTINATION calendar.
///
/// `keepAlive: true` for the same reason as the other settings above —
/// read by the Timeline screen, not screen-scoped state. Defaults to an
/// empty list when nothing is stored, so a fresh install (or one where the
/// user has never opened Settings' Calendar section) shows no external
/// events, matching the Timeline's previous calendar-free behavior.
final class CalendarDisplayIdsSettingProvider
    extends $NotifierProvider<CalendarDisplayIdsSetting, List<String>> {
  /// Which device calendars' events display (read-only) on the Timeline —
  /// Feature 1 of CONSTITUTION.md's "Calendar" section, a multi-select
  /// SOURCE list distinct from [CalendarSyncTargetIdSetting]'s single
  /// DESTINATION calendar.
  ///
  /// `keepAlive: true` for the same reason as the other settings above —
  /// read by the Timeline screen, not screen-scoped state. Defaults to an
  /// empty list when nothing is stored, so a fresh install (or one where the
  /// user has never opened Settings' Calendar section) shows no external
  /// events, matching the Timeline's previous calendar-free behavior.
  CalendarDisplayIdsSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarDisplayIdsSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarDisplayIdsSettingHash();

  @$internal
  @override
  CalendarDisplayIdsSetting create() => CalendarDisplayIdsSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$calendarDisplayIdsSettingHash() =>
    r'02a2672bd2c6e06ee4da4cea17ca11aa5abf7d9b';

/// Which device calendars' events display (read-only) on the Timeline —
/// Feature 1 of CONSTITUTION.md's "Calendar" section, a multi-select
/// SOURCE list distinct from [CalendarSyncTargetIdSetting]'s single
/// DESTINATION calendar.
///
/// `keepAlive: true` for the same reason as the other settings above —
/// read by the Timeline screen, not screen-scoped state. Defaults to an
/// empty list when nothing is stored, so a fresh install (or one where the
/// user has never opened Settings' Calendar section) shows no external
/// events, matching the Timeline's previous calendar-free behavior.

abstract class _$CalendarDisplayIdsSetting extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The single device calendar Amble tasks sync OUT to — Feature 2, a
/// single-select DESTINATION distinct from [CalendarDisplayIdsSetting]'s
/// multi-select SOURCE list above. Null means no target chosen yet.

@ProviderFor(CalendarSyncTargetIdSetting)
final calendarSyncTargetIdSettingProvider =
    CalendarSyncTargetIdSettingProvider._();

/// The single device calendar Amble tasks sync OUT to — Feature 2, a
/// single-select DESTINATION distinct from [CalendarDisplayIdsSetting]'s
/// multi-select SOURCE list above. Null means no target chosen yet.
final class CalendarSyncTargetIdSettingProvider
    extends $NotifierProvider<CalendarSyncTargetIdSetting, String?> {
  /// The single device calendar Amble tasks sync OUT to — Feature 2, a
  /// single-select DESTINATION distinct from [CalendarDisplayIdsSetting]'s
  /// multi-select SOURCE list above. Null means no target chosen yet.
  CalendarSyncTargetIdSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarSyncTargetIdSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarSyncTargetIdSettingHash();

  @$internal
  @override
  CalendarSyncTargetIdSetting create() => CalendarSyncTargetIdSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$calendarSyncTargetIdSettingHash() =>
    r'4697e6bab8eaf3dbd386a95e18420efe3665a6d3';

/// The single device calendar Amble tasks sync OUT to — Feature 2, a
/// single-select DESTINATION distinct from [CalendarDisplayIdsSetting]'s
/// multi-select SOURCE list above. Null means no target chosen yet.

abstract class _$CalendarSyncTargetIdSetting extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The user-configured Slack Incoming Webhook URL for the automatic
/// morning summary — a plain, user-managed webhook, not an Amble-side
/// Slack app/OAuth connection. Absent (null) means the feature has nothing
/// to send to yet, independent of whether [SlackSummaryEnabledSetting] is
/// on — the two are deliberately separate flags (see that provider's own
/// doc comment) rather than one setting inferred from "URL is non-empty."

@ProviderFor(SlackWebhookUrlSetting)
final slackWebhookUrlSettingProvider = SlackWebhookUrlSettingProvider._();

/// The user-configured Slack Incoming Webhook URL for the automatic
/// morning summary — a plain, user-managed webhook, not an Amble-side
/// Slack app/OAuth connection. Absent (null) means the feature has nothing
/// to send to yet, independent of whether [SlackSummaryEnabledSetting] is
/// on — the two are deliberately separate flags (see that provider's own
/// doc comment) rather than one setting inferred from "URL is non-empty."
final class SlackWebhookUrlSettingProvider
    extends $NotifierProvider<SlackWebhookUrlSetting, String?> {
  /// The user-configured Slack Incoming Webhook URL for the automatic
  /// morning summary — a plain, user-managed webhook, not an Amble-side
  /// Slack app/OAuth connection. Absent (null) means the feature has nothing
  /// to send to yet, independent of whether [SlackSummaryEnabledSetting] is
  /// on — the two are deliberately separate flags (see that provider's own
  /// doc comment) rather than one setting inferred from "URL is non-empty."
  SlackWebhookUrlSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slackWebhookUrlSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slackWebhookUrlSettingHash();

  @$internal
  @override
  SlackWebhookUrlSetting create() => SlackWebhookUrlSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$slackWebhookUrlSettingHash() =>
    r'6f63d717fd912ac93c4686407e0a6c07cd09904b';

/// The user-configured Slack Incoming Webhook URL for the automatic
/// morning summary — a plain, user-managed webhook, not an Amble-side
/// Slack app/OAuth connection. Absent (null) means the feature has nothing
/// to send to yet, independent of whether [SlackSummaryEnabledSetting] is
/// on — the two are deliberately separate flags (see that provider's own
/// doc comment) rather than one setting inferred from "URL is non-empty."

abstract class _$SlackWebhookUrlSetting extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the automatic morning summary is enabled. Defaults to **false**
/// — requested directly: pasting a webhook URL alone must not silently
/// turn on background sending; the user opts in explicitly. Read by the
/// background task registration in `core/background/background_tasks.dart`
/// to decide whether to (de)register the periodic task, and by the manual
/// "Send test message" button's own availability (a test send still needs
/// a URL, but doesn't require this toggle to be on — see the Settings
/// screen).

@ProviderFor(SlackSummaryEnabledSetting)
final slackSummaryEnabledSettingProvider =
    SlackSummaryEnabledSettingProvider._();

/// Whether the automatic morning summary is enabled. Defaults to **false**
/// — requested directly: pasting a webhook URL alone must not silently
/// turn on background sending; the user opts in explicitly. Read by the
/// background task registration in `core/background/background_tasks.dart`
/// to decide whether to (de)register the periodic task, and by the manual
/// "Send test message" button's own availability (a test send still needs
/// a URL, but doesn't require this toggle to be on — see the Settings
/// screen).
final class SlackSummaryEnabledSettingProvider
    extends $NotifierProvider<SlackSummaryEnabledSetting, bool> {
  /// Whether the automatic morning summary is enabled. Defaults to **false**
  /// — requested directly: pasting a webhook URL alone must not silently
  /// turn on background sending; the user opts in explicitly. Read by the
  /// background task registration in `core/background/background_tasks.dart`
  /// to decide whether to (de)register the periodic task, and by the manual
  /// "Send test message" button's own availability (a test send still needs
  /// a URL, but doesn't require this toggle to be on — see the Settings
  /// screen).
  SlackSummaryEnabledSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slackSummaryEnabledSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slackSummaryEnabledSettingHash();

  @$internal
  @override
  SlackSummaryEnabledSetting create() => SlackSummaryEnabledSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$slackSummaryEnabledSettingHash() =>
    r'ed30e465845cf76b5f420592a0a1ac01d051721f';

/// Whether the automatic morning summary is enabled. Defaults to **false**
/// — requested directly: pasting a webhook URL alone must not silently
/// turn on background sending; the user opts in explicitly. Read by the
/// background task registration in `core/background/background_tasks.dart`
/// to decide whether to (de)register the periodic task, and by the manual
/// "Send test message" button's own availability (a test send still needs
/// a URL, but doesn't require this toggle to be on — see the Settings
/// screen).

abstract class _$SlackSummaryEnabledSetting extends $Notifier<bool> {
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

/// Optional display-name override (Slack's `username` payload field).
/// Absent/blank omits the field entirely — see
/// `buildSlackPayload`'s own doc comment.

@ProviderFor(SlackDisplayNameSetting)
final slackDisplayNameSettingProvider = SlackDisplayNameSettingProvider._();

/// Optional display-name override (Slack's `username` payload field).
/// Absent/blank omits the field entirely — see
/// `buildSlackPayload`'s own doc comment.
final class SlackDisplayNameSettingProvider
    extends $NotifierProvider<SlackDisplayNameSetting, String?> {
  /// Optional display-name override (Slack's `username` payload field).
  /// Absent/blank omits the field entirely — see
  /// `buildSlackPayload`'s own doc comment.
  SlackDisplayNameSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slackDisplayNameSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slackDisplayNameSettingHash();

  @$internal
  @override
  SlackDisplayNameSetting create() => SlackDisplayNameSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$slackDisplayNameSettingHash() =>
    r'4368028ea29b62aee7562c58f78a3fb72f7f39f4';

/// Optional display-name override (Slack's `username` payload field).
/// Absent/blank omits the field entirely — see
/// `buildSlackPayload`'s own doc comment.

abstract class _$SlackDisplayNameSetting extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Optional icon-emoji override (Slack's `icon_emoji` payload field).
/// Same absent/blank-omits-the-field behavior as
/// [SlackDisplayNameSetting].

@ProviderFor(SlackIconEmojiSetting)
final slackIconEmojiSettingProvider = SlackIconEmojiSettingProvider._();

/// Optional icon-emoji override (Slack's `icon_emoji` payload field).
/// Same absent/blank-omits-the-field behavior as
/// [SlackDisplayNameSetting].
final class SlackIconEmojiSettingProvider
    extends $NotifierProvider<SlackIconEmojiSetting, String?> {
  /// Optional icon-emoji override (Slack's `icon_emoji` payload field).
  /// Same absent/blank-omits-the-field behavior as
  /// [SlackDisplayNameSetting].
  SlackIconEmojiSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slackIconEmojiSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slackIconEmojiSettingHash();

  @$internal
  @override
  SlackIconEmojiSetting create() => SlackIconEmojiSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$slackIconEmojiSettingHash() =>
    r'20f9452fb0f03b24aab48a677fe921fb8970cd3f';

/// Optional icon-emoji override (Slack's `icon_emoji` payload field).
/// Same absent/blank-omits-the-field behavior as
/// [SlackDisplayNameSetting].

abstract class _$SlackIconEmojiSetting extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
