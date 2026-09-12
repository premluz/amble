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

/// List view only — a standalone `1h`-style duration label per row (see
/// [DevTimelineTaskTimeRangeVisible] for the separate from-to time
/// setting). The two are independent: either, both, or neither can be on.
///
/// Task view's own split-layout duration column
/// (`TaskCapsuleTextRow.durationVisible`'s non-`compactInlineLayout`
/// branch) is untouched by this provider — confirmed directly: "these
/// should affect list view only and should not affect task spatial view
/// (on this view we'd never show this)." Previously this same provider
/// fed BOTH a List-view duration suffix appended onto the time string AND
/// Task view's split-layout column, conflating two different views'
/// concerns in one flag; the List-view half of that is what this
/// doc comment (and `TaskCapsuleTextRow`'s own `compactInlineLayout`
/// branch) now describes — the Task-view half is unchanged.

@ProviderFor(DevTimelineTaskDurationVisible)
final devTimelineTaskDurationVisibleProvider =
    DevTimelineTaskDurationVisibleProvider._();

/// List view only — a standalone `1h`-style duration label per row (see
/// [DevTimelineTaskTimeRangeVisible] for the separate from-to time
/// setting). The two are independent: either, both, or neither can be on.
///
/// Task view's own split-layout duration column
/// (`TaskCapsuleTextRow.durationVisible`'s non-`compactInlineLayout`
/// branch) is untouched by this provider — confirmed directly: "these
/// should affect list view only and should not affect task spatial view
/// (on this view we'd never show this)." Previously this same provider
/// fed BOTH a List-view duration suffix appended onto the time string AND
/// Task view's split-layout column, conflating two different views'
/// concerns in one flag; the List-view half of that is what this
/// doc comment (and `TaskCapsuleTextRow`'s own `compactInlineLayout`
/// branch) now describes — the Task-view half is unchanged.
final class DevTimelineTaskDurationVisibleProvider
    extends $NotifierProvider<DevTimelineTaskDurationVisible, bool> {
  /// List view only — a standalone `1h`-style duration label per row (see
  /// [DevTimelineTaskTimeRangeVisible] for the separate from-to time
  /// setting). The two are independent: either, both, or neither can be on.
  ///
  /// Task view's own split-layout duration column
  /// (`TaskCapsuleTextRow.durationVisible`'s non-`compactInlineLayout`
  /// branch) is untouched by this provider — confirmed directly: "these
  /// should affect list view only and should not affect task spatial view
  /// (on this view we'd never show this)." Previously this same provider
  /// fed BOTH a List-view duration suffix appended onto the time string AND
  /// Task view's split-layout column, conflating two different views'
  /// concerns in one flag; the List-view half of that is what this
  /// doc comment (and `TaskCapsuleTextRow`'s own `compactInlineLayout`
  /// branch) now describes — the Task-view half is unchanged.
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

/// List view only — a standalone `1h`-style duration label per row (see
/// [DevTimelineTaskTimeRangeVisible] for the separate from-to time
/// setting). The two are independent: either, both, or neither can be on.
///
/// Task view's own split-layout duration column
/// (`TaskCapsuleTextRow.durationVisible`'s non-`compactInlineLayout`
/// branch) is untouched by this provider — confirmed directly: "these
/// should affect list view only and should not affect task spatial view
/// (on this view we'd never show this)." Previously this same provider
/// fed BOTH a List-view duration suffix appended onto the time string AND
/// Task view's split-layout column, conflating two different views'
/// concerns in one flag; the List-view half of that is what this
/// doc comment (and `TaskCapsuleTextRow`'s own `compactInlineLayout`
/// branch) now describes — the Task-view half is unchanged.

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

/// List view only — the `04:20 - 05:20`-style time range per row.
/// Independent of [DevTimelineTaskDurationVisible] — see that provider's
/// own doc comment. Requested directly: "we should add setting show time
/// from to (should then show time)... these should affect list view only
/// and should not affect task spatial view."
///
/// **Default flipped to OFF as of 2026-09-10** (confirmed directly —
/// "show time off as default"), reversing its original launch default
/// (which matched List view's previous always-shown time range before
/// this toggle existed).

@ProviderFor(DevTimelineTaskTimeRangeVisible)
final devTimelineTaskTimeRangeVisibleProvider =
    DevTimelineTaskTimeRangeVisibleProvider._();

/// List view only — the `04:20 - 05:20`-style time range per row.
/// Independent of [DevTimelineTaskDurationVisible] — see that provider's
/// own doc comment. Requested directly: "we should add setting show time
/// from to (should then show time)... these should affect list view only
/// and should not affect task spatial view."
///
/// **Default flipped to OFF as of 2026-09-10** (confirmed directly —
/// "show time off as default"), reversing its original launch default
/// (which matched List view's previous always-shown time range before
/// this toggle existed).
final class DevTimelineTaskTimeRangeVisibleProvider
    extends $NotifierProvider<DevTimelineTaskTimeRangeVisible, bool> {
  /// List view only — the `04:20 - 05:20`-style time range per row.
  /// Independent of [DevTimelineTaskDurationVisible] — see that provider's
  /// own doc comment. Requested directly: "we should add setting show time
  /// from to (should then show time)... these should affect list view only
  /// and should not affect task spatial view."
  ///
  /// **Default flipped to OFF as of 2026-09-10** (confirmed directly —
  /// "show time off as default"), reversing its original launch default
  /// (which matched List view's previous always-shown time range before
  /// this toggle existed).
  DevTimelineTaskTimeRangeVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTimelineTaskTimeRangeVisibleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTimelineTaskTimeRangeVisibleHash();

  @$internal
  @override
  DevTimelineTaskTimeRangeVisible create() => DevTimelineTaskTimeRangeVisible();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devTimelineTaskTimeRangeVisibleHash() =>
    r'705cd9a21044e034e1648fceee398caf511415df';

/// List view only — the `04:20 - 05:20`-style time range per row.
/// Independent of [DevTimelineTaskDurationVisible] — see that provider's
/// own doc comment. Requested directly: "we should add setting show time
/// from to (should then show time)... these should affect list view only
/// and should not affect task spatial view."
///
/// **Default flipped to OFF as of 2026-09-10** (confirmed directly —
/// "show time off as default"), reversing its original launch default
/// (which matched List view's previous always-shown time range before
/// this toggle existed).

abstract class _$DevTimelineTaskTimeRangeVisible extends $Notifier<bool> {
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

/// List view AND Zone view — when on, hides every imported calendar event
/// (`ExternalCalendarEvent`) from both, showing only native Amble [Task]s.
/// Originally "Only Amble tasks", List-view-only — **replaced 2026-09-10**
/// (requested directly: "add hide imported tasks control in dev mode and
/// that'd be affecting zone and list view and replace switch (amble tasks
/// only)"): renamed to describe what it actually does (hides imports,
/// rather than a positive "only these") and widened to also apply to Zone
/// view. Task view is still unaffected — it keeps mixing imported events
/// into its own layout exactly as today.
///
/// Defaults to false (current shipped behavior: both views already mix
/// imported events in, same as Task view) — this toggle only ever REMOVES
/// events, never adds a display mode that didn't exist.

@ProviderFor(DevHideImportedTasks)
final devHideImportedTasksProvider = DevHideImportedTasksProvider._();

/// List view AND Zone view — when on, hides every imported calendar event
/// (`ExternalCalendarEvent`) from both, showing only native Amble [Task]s.
/// Originally "Only Amble tasks", List-view-only — **replaced 2026-09-10**
/// (requested directly: "add hide imported tasks control in dev mode and
/// that'd be affecting zone and list view and replace switch (amble tasks
/// only)"): renamed to describe what it actually does (hides imports,
/// rather than a positive "only these") and widened to also apply to Zone
/// view. Task view is still unaffected — it keeps mixing imported events
/// into its own layout exactly as today.
///
/// Defaults to false (current shipped behavior: both views already mix
/// imported events in, same as Task view) — this toggle only ever REMOVES
/// events, never adds a display mode that didn't exist.
final class DevHideImportedTasksProvider
    extends $NotifierProvider<DevHideImportedTasks, bool> {
  /// List view AND Zone view — when on, hides every imported calendar event
  /// (`ExternalCalendarEvent`) from both, showing only native Amble [Task]s.
  /// Originally "Only Amble tasks", List-view-only — **replaced 2026-09-10**
  /// (requested directly: "add hide imported tasks control in dev mode and
  /// that'd be affecting zone and list view and replace switch (amble tasks
  /// only)"): renamed to describe what it actually does (hides imports,
  /// rather than a positive "only these") and widened to also apply to Zone
  /// view. Task view is still unaffected — it keeps mixing imported events
  /// into its own layout exactly as today.
  ///
  /// Defaults to false (current shipped behavior: both views already mix
  /// imported events in, same as Task view) — this toggle only ever REMOVES
  /// events, never adds a display mode that didn't exist.
  DevHideImportedTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devHideImportedTasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devHideImportedTasksHash();

  @$internal
  @override
  DevHideImportedTasks create() => DevHideImportedTasks();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devHideImportedTasksHash() =>
    r'f6ba69cf691c0e4231a8117409ef13ba226a33b4';

/// List view AND Zone view — when on, hides every imported calendar event
/// (`ExternalCalendarEvent`) from both, showing only native Amble [Task]s.
/// Originally "Only Amble tasks", List-view-only — **replaced 2026-09-10**
/// (requested directly: "add hide imported tasks control in dev mode and
/// that'd be affecting zone and list view and replace switch (amble tasks
/// only)"): renamed to describe what it actually does (hides imports,
/// rather than a positive "only these") and widened to also apply to Zone
/// view. Task view is still unaffected — it keeps mixing imported events
/// into its own layout exactly as today.
///
/// Defaults to false (current shipped behavior: both views already mix
/// imported events in, same as Task view) — this toggle only ever REMOVES
/// events, never adds a display mode that didn't exist.

abstract class _$DevHideImportedTasks extends $Notifier<bool> {
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

/// Zone (grid) view only — when on, strips [ZoneContainerBlock]'s own
/// background fill/border AND its padding, leaving just the bare title +
/// duration header directly above its flat list of member task/event
/// rows, with no card chrome around either. Requested directly: "add a
/// control in admin that affects the grid zone view and removes the
/// background from zones and[,] uh, padding as well[;] so what's left is
/// a title[,] and underneath the tasks related inside this zone[,] and
/// duration[,] of course, also stays."
///
/// Task view's `ZoneBackgroundBlock` (the purely decorative fill on the
/// Spatial Task View) is unaffected — this only touches the Zone view's
/// own real layout container, which is the one actually described as a
/// "card" with a background/padding to remove.
///
/// Defaults to false (current shipped behavior: the card fill/padding
/// stays) — this toggle only ever REMOVES chrome, never adds a display
/// mode that didn't exist.

@ProviderFor(DevZoneCardFlat)
final devZoneCardFlatProvider = DevZoneCardFlatProvider._();

/// Zone (grid) view only — when on, strips [ZoneContainerBlock]'s own
/// background fill/border AND its padding, leaving just the bare title +
/// duration header directly above its flat list of member task/event
/// rows, with no card chrome around either. Requested directly: "add a
/// control in admin that affects the grid zone view and removes the
/// background from zones and[,] uh, padding as well[;] so what's left is
/// a title[,] and underneath the tasks related inside this zone[,] and
/// duration[,] of course, also stays."
///
/// Task view's `ZoneBackgroundBlock` (the purely decorative fill on the
/// Spatial Task View) is unaffected — this only touches the Zone view's
/// own real layout container, which is the one actually described as a
/// "card" with a background/padding to remove.
///
/// Defaults to false (current shipped behavior: the card fill/padding
/// stays) — this toggle only ever REMOVES chrome, never adds a display
/// mode that didn't exist.
final class DevZoneCardFlatProvider
    extends $NotifierProvider<DevZoneCardFlat, bool> {
  /// Zone (grid) view only — when on, strips [ZoneContainerBlock]'s own
  /// background fill/border AND its padding, leaving just the bare title +
  /// duration header directly above its flat list of member task/event
  /// rows, with no card chrome around either. Requested directly: "add a
  /// control in admin that affects the grid zone view and removes the
  /// background from zones and[,] uh, padding as well[;] so what's left is
  /// a title[,] and underneath the tasks related inside this zone[,] and
  /// duration[,] of course, also stays."
  ///
  /// Task view's `ZoneBackgroundBlock` (the purely decorative fill on the
  /// Spatial Task View) is unaffected — this only touches the Zone view's
  /// own real layout container, which is the one actually described as a
  /// "card" with a background/padding to remove.
  ///
  /// Defaults to false (current shipped behavior: the card fill/padding
  /// stays) — this toggle only ever REMOVES chrome, never adds a display
  /// mode that didn't exist.
  DevZoneCardFlatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devZoneCardFlatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devZoneCardFlatHash();

  @$internal
  @override
  DevZoneCardFlat create() => DevZoneCardFlat();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devZoneCardFlatHash() => r'0d691ffec0102cbcafe6838221093c69bf09cbd5';

/// Zone (grid) view only — when on, strips [ZoneContainerBlock]'s own
/// background fill/border AND its padding, leaving just the bare title +
/// duration header directly above its flat list of member task/event
/// rows, with no card chrome around either. Requested directly: "add a
/// control in admin that affects the grid zone view and removes the
/// background from zones and[,] uh, padding as well[;] so what's left is
/// a title[,] and underneath the tasks related inside this zone[,] and
/// duration[,] of course, also stays."
///
/// Task view's `ZoneBackgroundBlock` (the purely decorative fill on the
/// Spatial Task View) is unaffected — this only touches the Zone view's
/// own real layout container, which is the one actually described as a
/// "card" with a background/padding to remove.
///
/// Defaults to false (current shipped behavior: the card fill/padding
/// stays) — this toggle only ever REMOVES chrome, never adds a display
/// mode that didn't exist.

abstract class _$DevZoneCardFlat extends $Notifier<bool> {
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

/// List view only — when on, hides every [Task] with `isImportant == false`
/// from the row list. Requested directly as "config (only important)",
/// alongside [DevHideImportedTasks] above. Task view and Zone view
/// are unaffected — both show every task regardless of this toggle.
///
/// Imported calendar events have no `isImportant` concept at all, so this
/// toggle never touches them either way — it only filters [Task] rows.
/// Independent of [DevHideImportedTasks]: both, either, or neither
/// can be on, same "independent toggles" shape as the duration/time-range
/// pair above.
///
/// Defaults to false (current shipped behavior: List view shows every
/// task, important or not).

@ProviderFor(DevTimelineListOnlyImportant)
final devTimelineListOnlyImportantProvider =
    DevTimelineListOnlyImportantProvider._();

/// List view only — when on, hides every [Task] with `isImportant == false`
/// from the row list. Requested directly as "config (only important)",
/// alongside [DevHideImportedTasks] above. Task view and Zone view
/// are unaffected — both show every task regardless of this toggle.
///
/// Imported calendar events have no `isImportant` concept at all, so this
/// toggle never touches them either way — it only filters [Task] rows.
/// Independent of [DevHideImportedTasks]: both, either, or neither
/// can be on, same "independent toggles" shape as the duration/time-range
/// pair above.
///
/// Defaults to false (current shipped behavior: List view shows every
/// task, important or not).
final class DevTimelineListOnlyImportantProvider
    extends $NotifierProvider<DevTimelineListOnlyImportant, bool> {
  /// List view only — when on, hides every [Task] with `isImportant == false`
  /// from the row list. Requested directly as "config (only important)",
  /// alongside [DevHideImportedTasks] above. Task view and Zone view
  /// are unaffected — both show every task regardless of this toggle.
  ///
  /// Imported calendar events have no `isImportant` concept at all, so this
  /// toggle never touches them either way — it only filters [Task] rows.
  /// Independent of [DevHideImportedTasks]: both, either, or neither
  /// can be on, same "independent toggles" shape as the duration/time-range
  /// pair above.
  ///
  /// Defaults to false (current shipped behavior: List view shows every
  /// task, important or not).
  DevTimelineListOnlyImportantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTimelineListOnlyImportantProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTimelineListOnlyImportantHash();

  @$internal
  @override
  DevTimelineListOnlyImportant create() => DevTimelineListOnlyImportant();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devTimelineListOnlyImportantHash() =>
    r'd265a0905a02eb8dde1780e41014da49a1d27b70';

/// List view only — when on, hides every [Task] with `isImportant == false`
/// from the row list. Requested directly as "config (only important)",
/// alongside [DevHideImportedTasks] above. Task view and Zone view
/// are unaffected — both show every task regardless of this toggle.
///
/// Imported calendar events have no `isImportant` concept at all, so this
/// toggle never touches them either way — it only filters [Task] rows.
/// Independent of [DevHideImportedTasks]: both, either, or neither
/// can be on, same "independent toggles" shape as the duration/time-range
/// pair above.
///
/// Defaults to false (current shipped behavior: List view shows every
/// task, important or not).

abstract class _$DevTimelineListOnlyImportant extends $Notifier<bool> {
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
/// container barely fit itsS own header, let alone a task row, which is
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
/// container barely fit itsS own header, let alone a task row, which is
/// what caused the reported "missing gap between adjacent zones" (the
/// container was forced to grow past its gap-shrunk floor on nearly every
/// zone, not just unusually packed ones).
final class DevTaskViewPixelsPerMinuteProvider
    extends $NotifierProvider<DevTaskViewPixelsPerMinute, double> {
  /// Vertical timeline scale — pixels per minute — for the Spatial Task
  /// View. Requested directly as a scratch config so the right value can be
  /// dialed in live, separate from the Zone view's own scale below: at the
  /// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
  /// container barely fit itsS own header, let alone a task row, which is
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
/// container barely fit itsS own header, let alone a task row, which is
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

/// Whether List view is reachable at all from the Timeline's own
/// view-cycle button — **replaces the old `DevZoneViewInCycle`**
/// (2026-09-10, requested directly: "we have setting zone view off in dev
/// switching timeline cycles, but actually that'd be list view off now,
/// zone view and task view are on always, and list view as default off").
/// Zone view no longer has a debug-only way to be hidden from the cycle
/// at all — its reachability now depends purely on
/// `FeatureFlags.zoneEnabled`, same as a release build. Task view is
/// never skippable either (see `day_strip.dart`'s own `next()`). List
/// view is the only mode this toggle can remove, and it defaults to
/// OFF — the opposite of Zone view's own old on-by-default-then-off
/// history, since List view is the one being newly excluded by default
/// here, not Zone view being newly frozen.
///
/// Turning it off while List view happens to be the active mode falls
/// back to Task view, rather than stranding the user in a mode the
/// button can no longer cycle out of — same "don't strand the user"
/// contract the old Zone toggle had.

@ProviderFor(DevListViewInCycle)
final devListViewInCycleProvider = DevListViewInCycleProvider._();

/// Whether List view is reachable at all from the Timeline's own
/// view-cycle button — **replaces the old `DevZoneViewInCycle`**
/// (2026-09-10, requested directly: "we have setting zone view off in dev
/// switching timeline cycles, but actually that'd be list view off now,
/// zone view and task view are on always, and list view as default off").
/// Zone view no longer has a debug-only way to be hidden from the cycle
/// at all — its reachability now depends purely on
/// `FeatureFlags.zoneEnabled`, same as a release build. Task view is
/// never skippable either (see `day_strip.dart`'s own `next()`). List
/// view is the only mode this toggle can remove, and it defaults to
/// OFF — the opposite of Zone view's own old on-by-default-then-off
/// history, since List view is the one being newly excluded by default
/// here, not Zone view being newly frozen.
///
/// Turning it off while List view happens to be the active mode falls
/// back to Task view, rather than stranding the user in a mode the
/// button can no longer cycle out of — same "don't strand the user"
/// contract the old Zone toggle had.
final class DevListViewInCycleProvider
    extends $NotifierProvider<DevListViewInCycle, bool> {
  /// Whether List view is reachable at all from the Timeline's own
  /// view-cycle button — **replaces the old `DevZoneViewInCycle`**
  /// (2026-09-10, requested directly: "we have setting zone view off in dev
  /// switching timeline cycles, but actually that'd be list view off now,
  /// zone view and task view are on always, and list view as default off").
  /// Zone view no longer has a debug-only way to be hidden from the cycle
  /// at all — its reachability now depends purely on
  /// `FeatureFlags.zoneEnabled`, same as a release build. Task view is
  /// never skippable either (see `day_strip.dart`'s own `next()`). List
  /// view is the only mode this toggle can remove, and it defaults to
  /// OFF — the opposite of Zone view's own old on-by-default-then-off
  /// history, since List view is the one being newly excluded by default
  /// here, not Zone view being newly frozen.
  ///
  /// Turning it off while List view happens to be the active mode falls
  /// back to Task view, rather than stranding the user in a mode the
  /// button can no longer cycle out of — same "don't strand the user"
  /// contract the old Zone toggle had.
  DevListViewInCycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devListViewInCycleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devListViewInCycleHash();

  @$internal
  @override
  DevListViewInCycle create() => DevListViewInCycle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devListViewInCycleHash() =>
    r'02981fdff65060d008cb811a2fb476ca63ad3cc8';

/// Whether List view is reachable at all from the Timeline's own
/// view-cycle button — **replaces the old `DevZoneViewInCycle`**
/// (2026-09-10, requested directly: "we have setting zone view off in dev
/// switching timeline cycles, but actually that'd be list view off now,
/// zone view and task view are on always, and list view as default off").
/// Zone view no longer has a debug-only way to be hidden from the cycle
/// at all — its reachability now depends purely on
/// `FeatureFlags.zoneEnabled`, same as a release build. Task view is
/// never skippable either (see `day_strip.dart`'s own `next()`). List
/// view is the only mode this toggle can remove, and it defaults to
/// OFF — the opposite of Zone view's own old on-by-default-then-off
/// history, since List view is the one being newly excluded by default
/// here, not Zone view being newly frozen.
///
/// Turning it off while List view happens to be the active mode falls
/// back to Task view, rather than stranding the user in a mode the
/// button can no longer cycle out of — same "don't strand the user"
/// contract the old Zone toggle had.

abstract class _$DevListViewInCycle extends $Notifier<bool> {
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

/// Whether the "Tracked" bottom-nav tab is reachable at all. Mirrors
/// [DevZoneViewInCycle] exactly: default ON (matching
/// `FeatureFlags.trackedBehaviorEnabled`'s own new default), a debug-only
/// escape hatch to hide the tab again at runtime without a rebuild —
/// requested directly, alongside flipping the flag's default itself.
///
/// ANDs into the existing `FeatureFlags.trackedBehaviorEnabled` gate
/// rather than replacing it (see `main.dart`), so it can only ever REMOVE
/// the tab, never force it on where the flag itself says no. Turning it
/// off while the Tracked tab happens to be the selected one falls back to
/// a valid tab rather than stranding the user on an index that no longer
/// exists — see `_AmbleHomeState`'s own handling.

@ProviderFor(DevTrackedTabInCycle)
final devTrackedTabInCycleProvider = DevTrackedTabInCycleProvider._();

/// Whether the "Tracked" bottom-nav tab is reachable at all. Mirrors
/// [DevZoneViewInCycle] exactly: default ON (matching
/// `FeatureFlags.trackedBehaviorEnabled`'s own new default), a debug-only
/// escape hatch to hide the tab again at runtime without a rebuild —
/// requested directly, alongside flipping the flag's default itself.
///
/// ANDs into the existing `FeatureFlags.trackedBehaviorEnabled` gate
/// rather than replacing it (see `main.dart`), so it can only ever REMOVE
/// the tab, never force it on where the flag itself says no. Turning it
/// off while the Tracked tab happens to be the selected one falls back to
/// a valid tab rather than stranding the user on an index that no longer
/// exists — see `_AmbleHomeState`'s own handling.
final class DevTrackedTabInCycleProvider
    extends $NotifierProvider<DevTrackedTabInCycle, bool> {
  /// Whether the "Tracked" bottom-nav tab is reachable at all. Mirrors
  /// [DevZoneViewInCycle] exactly: default ON (matching
  /// `FeatureFlags.trackedBehaviorEnabled`'s own new default), a debug-only
  /// escape hatch to hide the tab again at runtime without a rebuild —
  /// requested directly, alongside flipping the flag's default itself.
  ///
  /// ANDs into the existing `FeatureFlags.trackedBehaviorEnabled` gate
  /// rather than replacing it (see `main.dart`), so it can only ever REMOVE
  /// the tab, never force it on where the flag itself says no. Turning it
  /// off while the Tracked tab happens to be the selected one falls back to
  /// a valid tab rather than stranding the user on an index that no longer
  /// exists — see `_AmbleHomeState`'s own handling.
  DevTrackedTabInCycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devTrackedTabInCycleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devTrackedTabInCycleHash();

  @$internal
  @override
  DevTrackedTabInCycle create() => DevTrackedTabInCycle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devTrackedTabInCycleHash() =>
    r'7588467130e5b1f0900fa78f8ba7e958ea185697';

/// Whether the "Tracked" bottom-nav tab is reachable at all. Mirrors
/// [DevZoneViewInCycle] exactly: default ON (matching
/// `FeatureFlags.trackedBehaviorEnabled`'s own new default), a debug-only
/// escape hatch to hide the tab again at runtime without a rebuild —
/// requested directly, alongside flipping the flag's default itself.
///
/// ANDs into the existing `FeatureFlags.trackedBehaviorEnabled` gate
/// rather than replacing it (see `main.dart`), so it can only ever REMOVE
/// the tab, never force it on where the flag itself says no. Turning it
/// off while the Tracked tab happens to be the selected one falls back to
/// a valid tab rather than stranding the user on an index that no longer
/// exists — see `_AmbleHomeState`'s own handling.

abstract class _$DevTrackedTabInCycle extends $Notifier<bool> {
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

/// Whether Edit Mode's multi-task selection route is active — requested
/// directly as a "configurable" alternative to the single-task Edit Mode
/// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
/// "Edit Mode" section). With this on, tap becomes select/deselect
/// (wiggle becomes the SELECTION indicator instead of the mode indicator
/// — only selected blocks wiggle), and drag/resize/delete on any selected
/// block acts on the whole selection. With it off, Edit Mode is
/// byte-for-byte the existing single-task behavior (every block wiggles,
/// tap opens the detail sheet, drag/resize/delete each act on one task).
///
/// **Default flipped to ON as of 2026-09-06** (confirmed directly — "turn
/// on as default multi edit view"), reversing this provider's own
/// original default-off launch decision.
///
/// Deliberately debug-only for now, same reasoning as
/// [DevTimelineTaskTextLayout] above: this is a big, still-settling
/// interaction model, not yet a finished product feature — promoting it
/// to a real `PreferenceKeys` setting (or a `FeatureFlags` gate) is a
/// separate, later decision once the model has been used for a while.
/// Unlike [DevZoneViewInCycle]/[DevTrackedTabInCycle] (which AND into an
/// already-shipped `FeatureFlags` gate), there is no such gate here to AND
/// into — this provider IS the only on/off switch multi-task mode has.

@ProviderFor(DevMultiTaskEditMode)
final devMultiTaskEditModeProvider = DevMultiTaskEditModeProvider._();

/// Whether Edit Mode's multi-task selection route is active — requested
/// directly as a "configurable" alternative to the single-task Edit Mode
/// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
/// "Edit Mode" section). With this on, tap becomes select/deselect
/// (wiggle becomes the SELECTION indicator instead of the mode indicator
/// — only selected blocks wiggle), and drag/resize/delete on any selected
/// block acts on the whole selection. With it off, Edit Mode is
/// byte-for-byte the existing single-task behavior (every block wiggles,
/// tap opens the detail sheet, drag/resize/delete each act on one task).
///
/// **Default flipped to ON as of 2026-09-06** (confirmed directly — "turn
/// on as default multi edit view"), reversing this provider's own
/// original default-off launch decision.
///
/// Deliberately debug-only for now, same reasoning as
/// [DevTimelineTaskTextLayout] above: this is a big, still-settling
/// interaction model, not yet a finished product feature — promoting it
/// to a real `PreferenceKeys` setting (or a `FeatureFlags` gate) is a
/// separate, later decision once the model has been used for a while.
/// Unlike [DevZoneViewInCycle]/[DevTrackedTabInCycle] (which AND into an
/// already-shipped `FeatureFlags` gate), there is no such gate here to AND
/// into — this provider IS the only on/off switch multi-task mode has.
final class DevMultiTaskEditModeProvider
    extends $NotifierProvider<DevMultiTaskEditMode, bool> {
  /// Whether Edit Mode's multi-task selection route is active — requested
  /// directly as a "configurable" alternative to the single-task Edit Mode
  /// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
  /// "Edit Mode" section). With this on, tap becomes select/deselect
  /// (wiggle becomes the SELECTION indicator instead of the mode indicator
  /// — only selected blocks wiggle), and drag/resize/delete on any selected
  /// block acts on the whole selection. With it off, Edit Mode is
  /// byte-for-byte the existing single-task behavior (every block wiggles,
  /// tap opens the detail sheet, drag/resize/delete each act on one task).
  ///
  /// **Default flipped to ON as of 2026-09-06** (confirmed directly — "turn
  /// on as default multi edit view"), reversing this provider's own
  /// original default-off launch decision.
  ///
  /// Deliberately debug-only for now, same reasoning as
  /// [DevTimelineTaskTextLayout] above: this is a big, still-settling
  /// interaction model, not yet a finished product feature — promoting it
  /// to a real `PreferenceKeys` setting (or a `FeatureFlags` gate) is a
  /// separate, later decision once the model has been used for a while.
  /// Unlike [DevZoneViewInCycle]/[DevTrackedTabInCycle] (which AND into an
  /// already-shipped `FeatureFlags` gate), there is no such gate here to AND
  /// into — this provider IS the only on/off switch multi-task mode has.
  DevMultiTaskEditModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devMultiTaskEditModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devMultiTaskEditModeHash();

  @$internal
  @override
  DevMultiTaskEditMode create() => DevMultiTaskEditMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$devMultiTaskEditModeHash() =>
    r'3435149016cf7b5331f39b570b5df9cf5125be05';

/// Whether Edit Mode's multi-task selection route is active — requested
/// directly as a "configurable" alternative to the single-task Edit Mode
/// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
/// "Edit Mode" section). With this on, tap becomes select/deselect
/// (wiggle becomes the SELECTION indicator instead of the mode indicator
/// — only selected blocks wiggle), and drag/resize/delete on any selected
/// block acts on the whole selection. With it off, Edit Mode is
/// byte-for-byte the existing single-task behavior (every block wiggles,
/// tap opens the detail sheet, drag/resize/delete each act on one task).
///
/// **Default flipped to ON as of 2026-09-06** (confirmed directly — "turn
/// on as default multi edit view"), reversing this provider's own
/// original default-off launch decision.
///
/// Deliberately debug-only for now, same reasoning as
/// [DevTimelineTaskTextLayout] above: this is a big, still-settling
/// interaction model, not yet a finished product feature — promoting it
/// to a real `PreferenceKeys` setting (or a `FeatureFlags` gate) is a
/// separate, later decision once the model has been used for a while.
/// Unlike [DevZoneViewInCycle]/[DevTrackedTabInCycle] (which AND into an
/// already-shipped `FeatureFlags` gate), there is no such gate here to AND
/// into — this provider IS the only on/off switch multi-task mode has.

abstract class _$DevMultiTaskEditMode extends $Notifier<bool> {
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
