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

/// Whether the onboarding Profile quiz has been completed or explicitly
/// skipped — see [PreferenceKeys.hasCompletedOnboarding]'s own doc
/// comment. `keepAlive: true` for the same reason as [HasSeenSplash]:
/// read by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state.

@ProviderFor(HasCompletedOnboarding)
final hasCompletedOnboardingProvider = HasCompletedOnboardingProvider._();

/// Whether the onboarding Profile quiz has been completed or explicitly
/// skipped — see [PreferenceKeys.hasCompletedOnboarding]'s own doc
/// comment. `keepAlive: true` for the same reason as [HasSeenSplash]:
/// read by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state.
final class HasCompletedOnboardingProvider
    extends $NotifierProvider<HasCompletedOnboarding, bool> {
  /// Whether the onboarding Profile quiz has been completed or explicitly
  /// skipped — see [PreferenceKeys.hasCompletedOnboarding]'s own doc
  /// comment. `keepAlive: true` for the same reason as [HasSeenSplash]:
  /// read by the root `MaterialApp` to decide its `home:`, not
  /// screen-scoped state.
  HasCompletedOnboardingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasCompletedOnboardingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasCompletedOnboardingHash();

  @$internal
  @override
  HasCompletedOnboarding create() => HasCompletedOnboarding();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasCompletedOnboardingHash() =>
    r'eded00ea67a975f32b7de180048a6d6b8c606c9b';

/// Whether the onboarding Profile quiz has been completed or explicitly
/// skipped — see [PreferenceKeys.hasCompletedOnboarding]'s own doc
/// comment. `keepAlive: true` for the same reason as [HasSeenSplash]:
/// read by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state.

abstract class _$HasCompletedOnboarding extends $Notifier<bool> {
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
/// directly). Defaults to **false** — changed 2026-09-19, requested
/// directly ("disable show timeline connects as default"), reversing the
/// original fresh-install-unchanged default above.

@ProviderFor(ShowTimelineConnectorsSetting)
final showTimelineConnectorsSettingProvider =
    ShowTimelineConnectorsSettingProvider._();

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **false** — changed 2026-09-19, requested
/// directly ("disable show timeline connects as default"), reversing the
/// original fresh-install-unchanged default above.
final class ShowTimelineConnectorsSettingProvider
    extends $NotifierProvider<ShowTimelineConnectorsSetting, bool> {
  /// Whether the gray thread connecting consecutive tasks
  /// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
  /// directly — configurable show/hide, Task view only (Zone view has no
  /// equivalent connector concept, its containers own child layout
  /// directly). Defaults to **false** — changed 2026-09-19, requested
  /// directly ("disable show timeline connects as default"), reversing the
  /// original fresh-install-unchanged default above.
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
    r'1959d3f41059f1aa44501e652a4cf9bf06f1c4bc';

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **false** — changed 2026-09-19, requested
/// directly ("disable show timeline connects as default"), reversing the
/// original fresh-install-unchanged default above.

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

/// The Timeline's own vertical time scale — pixels per minute — shared by
/// BOTH the spatial Task view and the Zone Grid/Edit screen. Requested
/// directly, alongside pinch-to-zoom: "we can set scale size in dev
/// settings... let's add pinch zoom in out timeline spatial in view and
/// edit modes (zones also) to zoom in and out scale" — confirmed via
/// AskUserQuestion as ONE shared, PERSISTED setting (not two independent
/// per-view values, and not a debug-only in-memory one), superseding:
/// - `DevTaskViewPixelsPerMinute`/`DevZoneViewPixelsPerMinute`
///   (`dev_config.dart`) — `kDebugMode`-only, in-memory, reset on every
///   restart; this is now the real thing those were a placeholder for.
/// - The Zone Grid's own previously-hardcoded `const _pixelsPerMinute =
///   44.0/60` (`zone_grid_screen.dart`) — a compile-time constant with no
///   setting behind it at all.
///
/// Clamped to [minPixelsPerMinute]/[maxPixelsPerMinute] (1.0–4.0),
/// matching the exact extremes the old dev-only preset chips already
/// exposed (`1.0, 1.5, 2.0, 3.0, 4.0`) — no new, previously-untested
/// extremes. Defaults to 1.5, the pre-existing default both old
/// mechanisms already used.

@ProviderFor(TimelinePixelsPerMinuteSetting)
final timelinePixelsPerMinuteSettingProvider =
    TimelinePixelsPerMinuteSettingProvider._();

/// The Timeline's own vertical time scale — pixels per minute — shared by
/// BOTH the spatial Task view and the Zone Grid/Edit screen. Requested
/// directly, alongside pinch-to-zoom: "we can set scale size in dev
/// settings... let's add pinch zoom in out timeline spatial in view and
/// edit modes (zones also) to zoom in and out scale" — confirmed via
/// AskUserQuestion as ONE shared, PERSISTED setting (not two independent
/// per-view values, and not a debug-only in-memory one), superseding:
/// - `DevTaskViewPixelsPerMinute`/`DevZoneViewPixelsPerMinute`
///   (`dev_config.dart`) — `kDebugMode`-only, in-memory, reset on every
///   restart; this is now the real thing those were a placeholder for.
/// - The Zone Grid's own previously-hardcoded `const _pixelsPerMinute =
///   44.0/60` (`zone_grid_screen.dart`) — a compile-time constant with no
///   setting behind it at all.
///
/// Clamped to [minPixelsPerMinute]/[maxPixelsPerMinute] (1.0–4.0),
/// matching the exact extremes the old dev-only preset chips already
/// exposed (`1.0, 1.5, 2.0, 3.0, 4.0`) — no new, previously-untested
/// extremes. Defaults to 1.5, the pre-existing default both old
/// mechanisms already used.
final class TimelinePixelsPerMinuteSettingProvider
    extends $NotifierProvider<TimelinePixelsPerMinuteSetting, double> {
  /// The Timeline's own vertical time scale — pixels per minute — shared by
  /// BOTH the spatial Task view and the Zone Grid/Edit screen. Requested
  /// directly, alongside pinch-to-zoom: "we can set scale size in dev
  /// settings... let's add pinch zoom in out timeline spatial in view and
  /// edit modes (zones also) to zoom in and out scale" — confirmed via
  /// AskUserQuestion as ONE shared, PERSISTED setting (not two independent
  /// per-view values, and not a debug-only in-memory one), superseding:
  /// - `DevTaskViewPixelsPerMinute`/`DevZoneViewPixelsPerMinute`
  ///   (`dev_config.dart`) — `kDebugMode`-only, in-memory, reset on every
  ///   restart; this is now the real thing those were a placeholder for.
  /// - The Zone Grid's own previously-hardcoded `const _pixelsPerMinute =
  ///   44.0/60` (`zone_grid_screen.dart`) — a compile-time constant with no
  ///   setting behind it at all.
  ///
  /// Clamped to [minPixelsPerMinute]/[maxPixelsPerMinute] (1.0–4.0),
  /// matching the exact extremes the old dev-only preset chips already
  /// exposed (`1.0, 1.5, 2.0, 3.0, 4.0`) — no new, previously-untested
  /// extremes. Defaults to 1.5, the pre-existing default both old
  /// mechanisms already used.
  TimelinePixelsPerMinuteSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timelinePixelsPerMinuteSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timelinePixelsPerMinuteSettingHash();

  @$internal
  @override
  TimelinePixelsPerMinuteSetting create() => TimelinePixelsPerMinuteSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$timelinePixelsPerMinuteSettingHash() =>
    r'fe3b2c9400c2f4265cf47854e8bdede8263d81f9';

/// The Timeline's own vertical time scale — pixels per minute — shared by
/// BOTH the spatial Task view and the Zone Grid/Edit screen. Requested
/// directly, alongside pinch-to-zoom: "we can set scale size in dev
/// settings... let's add pinch zoom in out timeline spatial in view and
/// edit modes (zones also) to zoom in and out scale" — confirmed via
/// AskUserQuestion as ONE shared, PERSISTED setting (not two independent
/// per-view values, and not a debug-only in-memory one), superseding:
/// - `DevTaskViewPixelsPerMinute`/`DevZoneViewPixelsPerMinute`
///   (`dev_config.dart`) — `kDebugMode`-only, in-memory, reset on every
///   restart; this is now the real thing those were a placeholder for.
/// - The Zone Grid's own previously-hardcoded `const _pixelsPerMinute =
///   44.0/60` (`zone_grid_screen.dart`) — a compile-time constant with no
///   setting behind it at all.
///
/// Clamped to [minPixelsPerMinute]/[maxPixelsPerMinute] (1.0–4.0),
/// matching the exact extremes the old dev-only preset chips already
/// exposed (`1.0, 1.5, 2.0, 3.0, 4.0`) — no new, previously-untested
/// extremes. Defaults to 1.5, the pre-existing default both old
/// mechanisms already used.

abstract class _$TimelinePixelsPerMinuteSetting extends $Notifier<double> {
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

/// Which rung of the task-title-FONT scale (`TaskFontSize.sm`/`md`/`lg`)
/// the Timeline renders title text at — independent of [TaskSizeSetting]'s
/// own badge/pill diameter. Requested directly: "Settings in appearance
/// separately font size and separately pill size, let's split this, and
/// should affect all pills its text."
///
/// `main.dart` reads this to `copyWith` the right `textTaskTitle*` field
/// onto the active `AmbleTheme`, mirroring [TaskSizeSetting]'s own
/// mechanism exactly — see `_resolveFontSize`.
///
/// **One-time migration, not a plain default** (confirmed via
/// AskUserQuestion): before this split, [TaskSizeSetting]'s own single
/// value drove BOTH the badge size and the font rung together (paired by
/// NAME — `TaskSize.sm` resolved to `textTaskTitleSm`, etc.). An absent
/// [PreferenceKeys.taskFontSize] means this user's device predates the
/// split, so [build] resolves it from whatever [TaskSizeSetting] currently
/// holds — by name, `TaskSize.sm` -> `TaskFontSize.sm` — rather than
/// silently resetting an existing user's font size to a fresh default the
/// moment this control becomes independent. A genuinely fresh install
/// (where [TaskSizeSetting] ALSO has nothing stored) falls through to that
/// same by-name mapping applied to `TaskSize`'s own default (`md`), so it
/// still lands on `TaskFontSize.md` — identical to [TaskSizeSetting]'s own
/// plain default, just reached via one extra (harmless) hop.
///
/// `build()` deliberately never WRITES — only resolves the value to
/// return, in memory. Real bug, caught by the full test suite hanging
/// indefinitely: an earlier version persisted the migrated value
/// immediately from inside `build()` via `unawaited(...)`, and any test
/// that mounted the app and tore down its Hive boxes before that
/// fire-and-forget write finished deadlocked on `deleteFromDisk()` — the
/// exact "unawaited Hive write still in flight when the test returned"
/// class of bug this codebase has hit before (see docs/ERROR_LOG.md). A
/// provider's `build()` performing I/O as a side effect is the wrong
/// place for this regardless of the test-hang symptom; [migrateIfNeeded]
/// below is the explicit, awaited, launch-time equivalent of every other
/// one-time migration in this app (see `main()`'s own
/// `materializeDueRecurrences`/`migrateToWeeklySchedule` calls).

@ProviderFor(TaskFontSizeSetting)
final taskFontSizeSettingProvider = TaskFontSizeSettingProvider._();

/// Which rung of the task-title-FONT scale (`TaskFontSize.sm`/`md`/`lg`)
/// the Timeline renders title text at — independent of [TaskSizeSetting]'s
/// own badge/pill diameter. Requested directly: "Settings in appearance
/// separately font size and separately pill size, let's split this, and
/// should affect all pills its text."
///
/// `main.dart` reads this to `copyWith` the right `textTaskTitle*` field
/// onto the active `AmbleTheme`, mirroring [TaskSizeSetting]'s own
/// mechanism exactly — see `_resolveFontSize`.
///
/// **One-time migration, not a plain default** (confirmed via
/// AskUserQuestion): before this split, [TaskSizeSetting]'s own single
/// value drove BOTH the badge size and the font rung together (paired by
/// NAME — `TaskSize.sm` resolved to `textTaskTitleSm`, etc.). An absent
/// [PreferenceKeys.taskFontSize] means this user's device predates the
/// split, so [build] resolves it from whatever [TaskSizeSetting] currently
/// holds — by name, `TaskSize.sm` -> `TaskFontSize.sm` — rather than
/// silently resetting an existing user's font size to a fresh default the
/// moment this control becomes independent. A genuinely fresh install
/// (where [TaskSizeSetting] ALSO has nothing stored) falls through to that
/// same by-name mapping applied to `TaskSize`'s own default (`md`), so it
/// still lands on `TaskFontSize.md` — identical to [TaskSizeSetting]'s own
/// plain default, just reached via one extra (harmless) hop.
///
/// `build()` deliberately never WRITES — only resolves the value to
/// return, in memory. Real bug, caught by the full test suite hanging
/// indefinitely: an earlier version persisted the migrated value
/// immediately from inside `build()` via `unawaited(...)`, and any test
/// that mounted the app and tore down its Hive boxes before that
/// fire-and-forget write finished deadlocked on `deleteFromDisk()` — the
/// exact "unawaited Hive write still in flight when the test returned"
/// class of bug this codebase has hit before (see docs/ERROR_LOG.md). A
/// provider's `build()` performing I/O as a side effect is the wrong
/// place for this regardless of the test-hang symptom; [migrateIfNeeded]
/// below is the explicit, awaited, launch-time equivalent of every other
/// one-time migration in this app (see `main()`'s own
/// `materializeDueRecurrences`/`migrateToWeeklySchedule` calls).
final class TaskFontSizeSettingProvider
    extends $NotifierProvider<TaskFontSizeSetting, TaskFontSize> {
  /// Which rung of the task-title-FONT scale (`TaskFontSize.sm`/`md`/`lg`)
  /// the Timeline renders title text at — independent of [TaskSizeSetting]'s
  /// own badge/pill diameter. Requested directly: "Settings in appearance
  /// separately font size and separately pill size, let's split this, and
  /// should affect all pills its text."
  ///
  /// `main.dart` reads this to `copyWith` the right `textTaskTitle*` field
  /// onto the active `AmbleTheme`, mirroring [TaskSizeSetting]'s own
  /// mechanism exactly — see `_resolveFontSize`.
  ///
  /// **One-time migration, not a plain default** (confirmed via
  /// AskUserQuestion): before this split, [TaskSizeSetting]'s own single
  /// value drove BOTH the badge size and the font rung together (paired by
  /// NAME — `TaskSize.sm` resolved to `textTaskTitleSm`, etc.). An absent
  /// [PreferenceKeys.taskFontSize] means this user's device predates the
  /// split, so [build] resolves it from whatever [TaskSizeSetting] currently
  /// holds — by name, `TaskSize.sm` -> `TaskFontSize.sm` — rather than
  /// silently resetting an existing user's font size to a fresh default the
  /// moment this control becomes independent. A genuinely fresh install
  /// (where [TaskSizeSetting] ALSO has nothing stored) falls through to that
  /// same by-name mapping applied to `TaskSize`'s own default (`md`), so it
  /// still lands on `TaskFontSize.md` — identical to [TaskSizeSetting]'s own
  /// plain default, just reached via one extra (harmless) hop.
  ///
  /// `build()` deliberately never WRITES — only resolves the value to
  /// return, in memory. Real bug, caught by the full test suite hanging
  /// indefinitely: an earlier version persisted the migrated value
  /// immediately from inside `build()` via `unawaited(...)`, and any test
  /// that mounted the app and tore down its Hive boxes before that
  /// fire-and-forget write finished deadlocked on `deleteFromDisk()` — the
  /// exact "unawaited Hive write still in flight when the test returned"
  /// class of bug this codebase has hit before (see docs/ERROR_LOG.md). A
  /// provider's `build()` performing I/O as a side effect is the wrong
  /// place for this regardless of the test-hang symptom; [migrateIfNeeded]
  /// below is the explicit, awaited, launch-time equivalent of every other
  /// one-time migration in this app (see `main()`'s own
  /// `materializeDueRecurrences`/`migrateToWeeklySchedule` calls).
  TaskFontSizeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskFontSizeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskFontSizeSettingHash();

  @$internal
  @override
  TaskFontSizeSetting create() => TaskFontSizeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskFontSize value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskFontSize>(value),
    );
  }
}

String _$taskFontSizeSettingHash() =>
    r'9c9a5ec16c1f7c22693d838e0a96db15c81d781a';

/// Which rung of the task-title-FONT scale (`TaskFontSize.sm`/`md`/`lg`)
/// the Timeline renders title text at — independent of [TaskSizeSetting]'s
/// own badge/pill diameter. Requested directly: "Settings in appearance
/// separately font size and separately pill size, let's split this, and
/// should affect all pills its text."
///
/// `main.dart` reads this to `copyWith` the right `textTaskTitle*` field
/// onto the active `AmbleTheme`, mirroring [TaskSizeSetting]'s own
/// mechanism exactly — see `_resolveFontSize`.
///
/// **One-time migration, not a plain default** (confirmed via
/// AskUserQuestion): before this split, [TaskSizeSetting]'s own single
/// value drove BOTH the badge size and the font rung together (paired by
/// NAME — `TaskSize.sm` resolved to `textTaskTitleSm`, etc.). An absent
/// [PreferenceKeys.taskFontSize] means this user's device predates the
/// split, so [build] resolves it from whatever [TaskSizeSetting] currently
/// holds — by name, `TaskSize.sm` -> `TaskFontSize.sm` — rather than
/// silently resetting an existing user's font size to a fresh default the
/// moment this control becomes independent. A genuinely fresh install
/// (where [TaskSizeSetting] ALSO has nothing stored) falls through to that
/// same by-name mapping applied to `TaskSize`'s own default (`md`), so it
/// still lands on `TaskFontSize.md` — identical to [TaskSizeSetting]'s own
/// plain default, just reached via one extra (harmless) hop.
///
/// `build()` deliberately never WRITES — only resolves the value to
/// return, in memory. Real bug, caught by the full test suite hanging
/// indefinitely: an earlier version persisted the migrated value
/// immediately from inside `build()` via `unawaited(...)`, and any test
/// that mounted the app and tore down its Hive boxes before that
/// fire-and-forget write finished deadlocked on `deleteFromDisk()` — the
/// exact "unawaited Hive write still in flight when the test returned"
/// class of bug this codebase has hit before (see docs/ERROR_LOG.md). A
/// provider's `build()` performing I/O as a side effect is the wrong
/// place for this regardless of the test-hang symptom; [migrateIfNeeded]
/// below is the explicit, awaited, launch-time equivalent of every other
/// one-time migration in this app (see `main()`'s own
/// `materializeDueRecurrences`/`migrateToWeeklySchedule` calls).

abstract class _$TaskFontSizeSetting extends $Notifier<TaskFontSize> {
  TaskFontSize build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TaskFontSize, TaskFontSize>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskFontSize, TaskFontSize>,
              TaskFontSize,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which corner-rounding a task/zone/Inbox pill badge renders at
/// (`PillShape.small`/`rounded`/`full`) — one global setting spanning
/// every pill-shaped surface in the app, mirroring [TaskSizeSetting]'s own
/// mechanism exactly. `main.dart` reads this to `copyWith` the right
/// `radiusPill` value onto the active `AmbleTheme` before it reaches
/// `MaterialApp`, so every existing call site (`TaskCapsuleBlock`,
/// `ZoneContainerBlock`, the Inbox row's own badge) picks it up
/// automatically without itself knowing this setting exists. Since
/// 2026-09-19, `AppButton`'s pill shape and `AppTabSwitch`'s track also
/// read the same active `radiusPill` — the setting is no longer scoped to
/// task/zone/Inbox badges alone, any pill-shaped control in the app tracks
/// it.
///
/// Requested directly: "we have squary rounded shape of pills but rounded
/// on inbox ... let's make it configurable in admin ... this should affect
/// globally, in edit tasks etc."
///
/// Defaults to `PillShape.full` — changed 2026-09-19 from the original
/// `PillShape.small` default, requested directly: "all buttons and other
/// related should be fully rounded... we actually have config rounding 3
/// variants for task pill we should use that fully rounded to match." The
/// setting itself, and its other two rungs, are unchanged — only which
/// rung a fresh install starts on.

@ProviderFor(PillShapeSetting)
final pillShapeSettingProvider = PillShapeSettingProvider._();

/// Which corner-rounding a task/zone/Inbox pill badge renders at
/// (`PillShape.small`/`rounded`/`full`) — one global setting spanning
/// every pill-shaped surface in the app, mirroring [TaskSizeSetting]'s own
/// mechanism exactly. `main.dart` reads this to `copyWith` the right
/// `radiusPill` value onto the active `AmbleTheme` before it reaches
/// `MaterialApp`, so every existing call site (`TaskCapsuleBlock`,
/// `ZoneContainerBlock`, the Inbox row's own badge) picks it up
/// automatically without itself knowing this setting exists. Since
/// 2026-09-19, `AppButton`'s pill shape and `AppTabSwitch`'s track also
/// read the same active `radiusPill` — the setting is no longer scoped to
/// task/zone/Inbox badges alone, any pill-shaped control in the app tracks
/// it.
///
/// Requested directly: "we have squary rounded shape of pills but rounded
/// on inbox ... let's make it configurable in admin ... this should affect
/// globally, in edit tasks etc."
///
/// Defaults to `PillShape.full` — changed 2026-09-19 from the original
/// `PillShape.small` default, requested directly: "all buttons and other
/// related should be fully rounded... we actually have config rounding 3
/// variants for task pill we should use that fully rounded to match." The
/// setting itself, and its other two rungs, are unchanged — only which
/// rung a fresh install starts on.
final class PillShapeSettingProvider
    extends $NotifierProvider<PillShapeSetting, PillShape> {
  /// Which corner-rounding a task/zone/Inbox pill badge renders at
  /// (`PillShape.small`/`rounded`/`full`) — one global setting spanning
  /// every pill-shaped surface in the app, mirroring [TaskSizeSetting]'s own
  /// mechanism exactly. `main.dart` reads this to `copyWith` the right
  /// `radiusPill` value onto the active `AmbleTheme` before it reaches
  /// `MaterialApp`, so every existing call site (`TaskCapsuleBlock`,
  /// `ZoneContainerBlock`, the Inbox row's own badge) picks it up
  /// automatically without itself knowing this setting exists. Since
  /// 2026-09-19, `AppButton`'s pill shape and `AppTabSwitch`'s track also
  /// read the same active `radiusPill` — the setting is no longer scoped to
  /// task/zone/Inbox badges alone, any pill-shaped control in the app tracks
  /// it.
  ///
  /// Requested directly: "we have squary rounded shape of pills but rounded
  /// on inbox ... let's make it configurable in admin ... this should affect
  /// globally, in edit tasks etc."
  ///
  /// Defaults to `PillShape.full` — changed 2026-09-19 from the original
  /// `PillShape.small` default, requested directly: "all buttons and other
  /// related should be fully rounded... we actually have config rounding 3
  /// variants for task pill we should use that fully rounded to match." The
  /// setting itself, and its other two rungs, are unchanged — only which
  /// rung a fresh install starts on.
  PillShapeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pillShapeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pillShapeSettingHash();

  @$internal
  @override
  PillShapeSetting create() => PillShapeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PillShape value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PillShape>(value),
    );
  }
}

String _$pillShapeSettingHash() => r'd4daac13d088ceaf416a049014904c44884d97b7';

/// Which corner-rounding a task/zone/Inbox pill badge renders at
/// (`PillShape.small`/`rounded`/`full`) — one global setting spanning
/// every pill-shaped surface in the app, mirroring [TaskSizeSetting]'s own
/// mechanism exactly. `main.dart` reads this to `copyWith` the right
/// `radiusPill` value onto the active `AmbleTheme` before it reaches
/// `MaterialApp`, so every existing call site (`TaskCapsuleBlock`,
/// `ZoneContainerBlock`, the Inbox row's own badge) picks it up
/// automatically without itself knowing this setting exists. Since
/// 2026-09-19, `AppButton`'s pill shape and `AppTabSwitch`'s track also
/// read the same active `radiusPill` — the setting is no longer scoped to
/// task/zone/Inbox badges alone, any pill-shaped control in the app tracks
/// it.
///
/// Requested directly: "we have squary rounded shape of pills but rounded
/// on inbox ... let's make it configurable in admin ... this should affect
/// globally, in edit tasks etc."
///
/// Defaults to `PillShape.full` — changed 2026-09-19 from the original
/// `PillShape.small` default, requested directly: "all buttons and other
/// related should be fully rounded... we actually have config rounding 3
/// variants for task pill we should use that fully rounded to match." The
/// setting itself, and its other two rungs, are unchanged — only which
/// rung a fresh install starts on.

abstract class _$PillShapeSetting extends $Notifier<PillShape> {
  PillShape build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PillShape, PillShape>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PillShape, PillShape>,
              PillShape,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether a Tag's color fills the WHOLE pill (`TagColorStyle.pill`) or
/// just the small badge behind its icon, with the rest of the pill paled
/// (`TagColorStyle.iconOnly`) — one global setting spanning every
/// pill-shaped surface in the app, mirroring [PillShapeSetting]'s own
/// mechanism exactly. Requested directly: "add config in admin that lets
/// [you] manage what gets the tag color as per tag (the pill or just the
/// icon...)."
///
/// Defaults to `TagColorStyle.pill` — today's existing, unchanged look.

@ProviderFor(TagColorStyleSetting)
final tagColorStyleSettingProvider = TagColorStyleSettingProvider._();

/// Whether a Tag's color fills the WHOLE pill (`TagColorStyle.pill`) or
/// just the small badge behind its icon, with the rest of the pill paled
/// (`TagColorStyle.iconOnly`) — one global setting spanning every
/// pill-shaped surface in the app, mirroring [PillShapeSetting]'s own
/// mechanism exactly. Requested directly: "add config in admin that lets
/// [you] manage what gets the tag color as per tag (the pill or just the
/// icon...)."
///
/// Defaults to `TagColorStyle.pill` — today's existing, unchanged look.
final class TagColorStyleSettingProvider
    extends $NotifierProvider<TagColorStyleSetting, TagColorStyle> {
  /// Whether a Tag's color fills the WHOLE pill (`TagColorStyle.pill`) or
  /// just the small badge behind its icon, with the rest of the pill paled
  /// (`TagColorStyle.iconOnly`) — one global setting spanning every
  /// pill-shaped surface in the app, mirroring [PillShapeSetting]'s own
  /// mechanism exactly. Requested directly: "add config in admin that lets
  /// [you] manage what gets the tag color as per tag (the pill or just the
  /// icon...)."
  ///
  /// Defaults to `TagColorStyle.pill` — today's existing, unchanged look.
  TagColorStyleSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagColorStyleSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagColorStyleSettingHash();

  @$internal
  @override
  TagColorStyleSetting create() => TagColorStyleSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TagColorStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TagColorStyle>(value),
    );
  }
}

String _$tagColorStyleSettingHash() =>
    r'8d4cb94bccd275dd238f8adc2d966e5cba92525a';

/// Whether a Tag's color fills the WHOLE pill (`TagColorStyle.pill`) or
/// just the small badge behind its icon, with the rest of the pill paled
/// (`TagColorStyle.iconOnly`) — one global setting spanning every
/// pill-shaped surface in the app, mirroring [PillShapeSetting]'s own
/// mechanism exactly. Requested directly: "add config in admin that lets
/// [you] manage what gets the tag color as per tag (the pill or just the
/// icon...)."
///
/// Defaults to `TagColorStyle.pill` — today's existing, unchanged look.

abstract class _$TagColorStyleSetting extends $Notifier<TagColorStyle> {
  TagColorStyle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TagColorStyle, TagColorStyle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TagColorStyle, TagColorStyle>,
              TagColorStyle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// How the "Tracked" screen's cards render a behavior's completion
/// history (weekly row / monthly grid / six-month heatmap) — one global
/// setting for the whole screen, cycled by a single switcher button in
/// its own bottom bar, mirroring the Timeline's `TimelineViewMode` cycle
/// button exactly. Defaults to `TrackedBehaviorViewMode.weekly`.

@ProviderFor(TrackedBehaviorViewModeSetting)
final trackedBehaviorViewModeSettingProvider =
    TrackedBehaviorViewModeSettingProvider._();

/// How the "Tracked" screen's cards render a behavior's completion
/// history (weekly row / monthly grid / six-month heatmap) — one global
/// setting for the whole screen, cycled by a single switcher button in
/// its own bottom bar, mirroring the Timeline's `TimelineViewMode` cycle
/// button exactly. Defaults to `TrackedBehaviorViewMode.weekly`.
final class TrackedBehaviorViewModeSettingProvider
    extends
        $NotifierProvider<
          TrackedBehaviorViewModeSetting,
          TrackedBehaviorViewMode
        > {
  /// How the "Tracked" screen's cards render a behavior's completion
  /// history (weekly row / monthly grid / six-month heatmap) — one global
  /// setting for the whole screen, cycled by a single switcher button in
  /// its own bottom bar, mirroring the Timeline's `TimelineViewMode` cycle
  /// button exactly. Defaults to `TrackedBehaviorViewMode.weekly`.
  TrackedBehaviorViewModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackedBehaviorViewModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackedBehaviorViewModeSettingHash();

  @$internal
  @override
  TrackedBehaviorViewModeSetting create() => TrackedBehaviorViewModeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackedBehaviorViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackedBehaviorViewMode>(value),
    );
  }
}

String _$trackedBehaviorViewModeSettingHash() =>
    r'9db87f71482c279df49a811828126a1638c5edac';

/// How the "Tracked" screen's cards render a behavior's completion
/// history (weekly row / monthly grid / six-month heatmap) — one global
/// setting for the whole screen, cycled by a single switcher button in
/// its own bottom bar, mirroring the Timeline's `TimelineViewMode` cycle
/// button exactly. Defaults to `TrackedBehaviorViewMode.weekly`.

abstract class _$TrackedBehaviorViewModeSetting
    extends $Notifier<TrackedBehaviorViewMode> {
  TrackedBehaviorViewMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TrackedBehaviorViewMode, TrackedBehaviorViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrackedBehaviorViewMode, TrackedBehaviorViewMode>,
              TrackedBehaviorViewMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the merged Timeline nav destination renders in Zone view —
/// Zones as real layout containers owning their child tasks' positions
/// (see `ZoneContainerBlock`) — instead of the default Task view (where
/// Zones are purely decorative background, see `ZoneBackgroundBlock`).
///
/// **2026-09-17 — live again.** Between 2026-09-12 and this date, Task
/// view and Zone view were two permanent, separate nav tabs and
/// `TimelineScreen` ignored this setting entirely (each tab forced its
/// own `TimelineDisplayMode`). Requested directly to consolidate back
/// into one nav item that toggles on a second tap or via
/// `AppCalendarHeader`'s own switcher button — this is that toggle's
/// real, read state again, not a harmless unread field.
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced (Dev settings toggle, header switcher button) when
/// `FeatureFlags.zoneEnabled` is also true — the setting itself has no
/// opinion on the flag; each surface decides its own visibility.

@ProviderFor(ZoneViewEnabledSetting)
final zoneViewEnabledSettingProvider = ZoneViewEnabledSettingProvider._();

/// Whether the merged Timeline nav destination renders in Zone view —
/// Zones as real layout containers owning their child tasks' positions
/// (see `ZoneContainerBlock`) — instead of the default Task view (where
/// Zones are purely decorative background, see `ZoneBackgroundBlock`).
///
/// **2026-09-17 — live again.** Between 2026-09-12 and this date, Task
/// view and Zone view were two permanent, separate nav tabs and
/// `TimelineScreen` ignored this setting entirely (each tab forced its
/// own `TimelineDisplayMode`). Requested directly to consolidate back
/// into one nav item that toggles on a second tap or via
/// `AppCalendarHeader`'s own switcher button — this is that toggle's
/// real, read state again, not a harmless unread field.
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced (Dev settings toggle, header switcher button) when
/// `FeatureFlags.zoneEnabled` is also true — the setting itself has no
/// opinion on the flag; each surface decides its own visibility.
final class ZoneViewEnabledSettingProvider
    extends $NotifierProvider<ZoneViewEnabledSetting, bool> {
  /// Whether the merged Timeline nav destination renders in Zone view —
  /// Zones as real layout containers owning their child tasks' positions
  /// (see `ZoneContainerBlock`) — instead of the default Task view (where
  /// Zones are purely decorative background, see `ZoneBackgroundBlock`).
  ///
  /// **2026-09-17 — live again.** Between 2026-09-12 and this date, Task
  /// view and Zone view were two permanent, separate nav tabs and
  /// `TimelineScreen` ignored this setting entirely (each tab forced its
  /// own `TimelineDisplayMode`). Requested directly to consolidate back
  /// into one nav item that toggles on a second tap or via
  /// `AppCalendarHeader`'s own switcher button — this is that toggle's
  /// real, read state again, not a harmless unread field.
  ///
  /// `keepAlive: true` for the same reason as the other settings above.
  /// Defaults to **false** when nothing is stored, so a fresh install (or an
  /// existing one) keeps today's Task view unless the user opts in. Only
  /// ever surfaced (Dev settings toggle, header switcher button) when
  /// `FeatureFlags.zoneEnabled` is also true — the setting itself has no
  /// opinion on the flag; each surface decides its own visibility.
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

/// Whether the merged Timeline nav destination renders in Zone view —
/// Zones as real layout containers owning their child tasks' positions
/// (see `ZoneContainerBlock`) — instead of the default Task view (where
/// Zones are purely decorative background, see `ZoneBackgroundBlock`).
///
/// **2026-09-17 — live again.** Between 2026-09-12 and this date, Task
/// view and Zone view were two permanent, separate nav tabs and
/// `TimelineScreen` ignored this setting entirely (each tab forced its
/// own `TimelineDisplayMode`). Requested directly to consolidate back
/// into one nav item that toggles on a second tap or via
/// `AppCalendarHeader`'s own switcher button — this is that toggle's
/// real, read state again, not a harmless unread field.
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced (Dev settings toggle, header switcher button) when
/// `FeatureFlags.zoneEnabled` is also true — the setting itself has no
/// opinion on the flag; each surface decides its own visibility.

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

/// Whether the "What Matters" lens is on — a persistent dock toggle
/// (`AppBottomDock`) that hides every [Task] with `isImportant == false`
/// entirely from the Timeline, in BOTH display modes (spatial and zone).
/// Requested directly as part of the nav redesign's bottom dock, reusing
/// the existing [Task.isImportant] flag rather than new data (confirmed
/// via AskUserQuestion). Reported directly on what "fades/collapses"
/// should mean here: "hide from view as if they were not there" — a real
/// filter, not a visual dimming.
///
/// Distinct from the pre-existing `DevTimelineListOnlyImportant` dev
/// toggle (`core/dev_config.dart`), which stays as its own separate,
/// debug-only scratch flag, List-view-only and independent of this one —
/// this is the real, persisted, user-facing equivalent, reachable in
/// release builds and applying to both Timeline modes.
///
/// `keepAlive: true` for the same reason as [ZoneViewEnabledSetting] —
/// read by the Timeline screen, not screen-scoped state. Defaults to
/// **false** when nothing is stored.

@ProviderFor(WhatMattersEnabledSetting)
final whatMattersEnabledSettingProvider = WhatMattersEnabledSettingProvider._();

/// Whether the "What Matters" lens is on — a persistent dock toggle
/// (`AppBottomDock`) that hides every [Task] with `isImportant == false`
/// entirely from the Timeline, in BOTH display modes (spatial and zone).
/// Requested directly as part of the nav redesign's bottom dock, reusing
/// the existing [Task.isImportant] flag rather than new data (confirmed
/// via AskUserQuestion). Reported directly on what "fades/collapses"
/// should mean here: "hide from view as if they were not there" — a real
/// filter, not a visual dimming.
///
/// Distinct from the pre-existing `DevTimelineListOnlyImportant` dev
/// toggle (`core/dev_config.dart`), which stays as its own separate,
/// debug-only scratch flag, List-view-only and independent of this one —
/// this is the real, persisted, user-facing equivalent, reachable in
/// release builds and applying to both Timeline modes.
///
/// `keepAlive: true` for the same reason as [ZoneViewEnabledSetting] —
/// read by the Timeline screen, not screen-scoped state. Defaults to
/// **false** when nothing is stored.
final class WhatMattersEnabledSettingProvider
    extends $NotifierProvider<WhatMattersEnabledSetting, bool> {
  /// Whether the "What Matters" lens is on — a persistent dock toggle
  /// (`AppBottomDock`) that hides every [Task] with `isImportant == false`
  /// entirely from the Timeline, in BOTH display modes (spatial and zone).
  /// Requested directly as part of the nav redesign's bottom dock, reusing
  /// the existing [Task.isImportant] flag rather than new data (confirmed
  /// via AskUserQuestion). Reported directly on what "fades/collapses"
  /// should mean here: "hide from view as if they were not there" — a real
  /// filter, not a visual dimming.
  ///
  /// Distinct from the pre-existing `DevTimelineListOnlyImportant` dev
  /// toggle (`core/dev_config.dart`), which stays as its own separate,
  /// debug-only scratch flag, List-view-only and independent of this one —
  /// this is the real, persisted, user-facing equivalent, reachable in
  /// release builds and applying to both Timeline modes.
  ///
  /// `keepAlive: true` for the same reason as [ZoneViewEnabledSetting] —
  /// read by the Timeline screen, not screen-scoped state. Defaults to
  /// **false** when nothing is stored.
  WhatMattersEnabledSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whatMattersEnabledSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whatMattersEnabledSettingHash();

  @$internal
  @override
  WhatMattersEnabledSetting create() => WhatMattersEnabledSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$whatMattersEnabledSettingHash() =>
    r'5881a0dd2da92799b07565e6af3cb5ff39d69ee6';

/// Whether the "What Matters" lens is on — a persistent dock toggle
/// (`AppBottomDock`) that hides every [Task] with `isImportant == false`
/// entirely from the Timeline, in BOTH display modes (spatial and zone).
/// Requested directly as part of the nav redesign's bottom dock, reusing
/// the existing [Task.isImportant] flag rather than new data (confirmed
/// via AskUserQuestion). Reported directly on what "fades/collapses"
/// should mean here: "hide from view as if they were not there" — a real
/// filter, not a visual dimming.
///
/// Distinct from the pre-existing `DevTimelineListOnlyImportant` dev
/// toggle (`core/dev_config.dart`), which stays as its own separate,
/// debug-only scratch flag, List-view-only and independent of this one —
/// this is the real, persisted, user-facing equivalent, reachable in
/// release builds and applying to both Timeline modes.
///
/// `keepAlive: true` for the same reason as [ZoneViewEnabledSetting] —
/// read by the Timeline screen, not screen-scoped state. Defaults to
/// **false** when nothing is stored.

abstract class _$WhatMattersEnabledSetting extends $Notifier<bool> {
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
