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
