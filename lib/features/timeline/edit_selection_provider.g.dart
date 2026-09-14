// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The set of task ids currently selected under Edit Mode's multi-task
/// route (`DevMultiTaskEditMode`, `core/dev_config.dart`) — requested
/// directly: with multi-task mode on, tapping a task selects it instead of
/// opening its detail sheet, and wiggle becomes the SELECTION indicator
/// (only selected blocks wiggle) rather than the mode indicator every
/// block shows under ordinary (single-task) Edit Mode.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled] (`edit_mode_provider.dart`): plain `autoDispose`, not
/// persisted, so a returning user never reopens into a stale selection.
/// Also cleared whenever Edit Mode itself is exited or multi-task mode is
/// toggled off — `timeline_screen.dart`'s own `ref.listen` wiring does
/// that, not this provider (a provider clearing itself in response to a
/// SIBLING provider's change is the wrong direction of coupling; the
/// screen already owns both toggles and is the natural place to react to
/// either one changing).

@ProviderFor(EditSelection)
final editSelectionProvider = EditSelectionProvider._();

/// The set of task ids currently selected under Edit Mode's multi-task
/// route (`DevMultiTaskEditMode`, `core/dev_config.dart`) — requested
/// directly: with multi-task mode on, tapping a task selects it instead of
/// opening its detail sheet, and wiggle becomes the SELECTION indicator
/// (only selected blocks wiggle) rather than the mode indicator every
/// block shows under ordinary (single-task) Edit Mode.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled] (`edit_mode_provider.dart`): plain `autoDispose`, not
/// persisted, so a returning user never reopens into a stale selection.
/// Also cleared whenever Edit Mode itself is exited or multi-task mode is
/// toggled off — `timeline_screen.dart`'s own `ref.listen` wiring does
/// that, not this provider (a provider clearing itself in response to a
/// SIBLING provider's change is the wrong direction of coupling; the
/// screen already owns both toggles and is the natural place to react to
/// either one changing).
final class EditSelectionProvider
    extends $NotifierProvider<EditSelection, Set<String>> {
  /// The set of task ids currently selected under Edit Mode's multi-task
  /// route (`DevMultiTaskEditMode`, `core/dev_config.dart`) — requested
  /// directly: with multi-task mode on, tapping a task selects it instead of
  /// opening its detail sheet, and wiggle becomes the SELECTION indicator
  /// (only selected blocks wiggle) rather than the mode indicator every
  /// block shows under ordinary (single-task) Edit Mode.
  ///
  /// Screen-local, ephemeral UI state — same reasoning and shape as
  /// [EditModeEnabled] (`edit_mode_provider.dart`): plain `autoDispose`, not
  /// persisted, so a returning user never reopens into a stale selection.
  /// Also cleared whenever Edit Mode itself is exited or multi-task mode is
  /// toggled off — `timeline_screen.dart`'s own `ref.listen` wiring does
  /// that, not this provider (a provider clearing itself in response to a
  /// SIBLING provider's change is the wrong direction of coupling; the
  /// screen already owns both toggles and is the natural place to react to
  /// either one changing).
  EditSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editSelectionHash();

  @$internal
  @override
  EditSelection create() => EditSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$editSelectionHash() => r'312cc83a174914eef58ecb5849f8e1b3a1d9e6cf';

/// The set of task ids currently selected under Edit Mode's multi-task
/// route (`DevMultiTaskEditMode`, `core/dev_config.dart`) — requested
/// directly: with multi-task mode on, tapping a task selects it instead of
/// opening its detail sheet, and wiggle becomes the SELECTION indicator
/// (only selected blocks wiggle) rather than the mode indicator every
/// block shows under ordinary (single-task) Edit Mode.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled] (`edit_mode_provider.dart`): plain `autoDispose`, not
/// persisted, so a returning user never reopens into a stale selection.
/// Also cleared whenever Edit Mode itself is exited or multi-task mode is
/// toggled off — `timeline_screen.dart`'s own `ref.listen` wiring does
/// that, not this provider (a provider clearing itself in response to a
/// SIBLING provider's change is the wrong direction of coupling; the
/// screen already owns both toggles and is the natural place to react to
/// either one changing).

abstract class _$EditSelection extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The set of ZONE ids currently selected under Edit Mode's multi-task
/// route — a separate provider from [EditSelection] (which holds TASK ids)
/// rather than one shared set, since the two are genuinely different
/// selections with no shared meaning (a task and a zone can never occupy
/// the same "selected" concept, and mixing their ids in one `Set<String>`
/// would make membership checks ambiguous about which kind of thing is
/// selected). **New 2026-09-06** (confirmed directly — zones should not
/// wiggle/be draggable in multi-task mode unless selected, mirroring the
/// existing task rule exactly): with multi-task mode on, tapping a zone's
/// header selects it instead of starting a move-drag, and wiggle becomes
/// the SELECTION indicator for zones too (only the selected zone wiggles)
/// rather than the mode indicator every zone shows under ordinary
/// (single-task) Edit Mode.
///
/// **Widened to genuine multi-select 2026-09-12** (was `String?`,
/// single-select). The original shape was justified by "there is no
/// group-zone-move feature" — that is no longer true: the Weekly Zone
/// Authoring Grid (`features/zone_grid/`) selects several zones at once
/// and moves/resizes them as a group, so this now mirrors
/// [EditSelection]'s `Set<String>` shape exactly.
///
/// Still a SEPARATE provider from [EditSelection] rather than one shared
/// set — that reasoning is unchanged and unrelated to cardinality: a task
/// id and a zone id have no shared meaning, and mixing them would make
/// membership checks ambiguous about which kind of thing is selected.
///
/// The Timeline's own zone selection (`_DraggableZoneBlock`) remains
/// effectively single-select in practice, because nothing there offers a
/// group gesture — it simply reads membership instead of equality now.
/// Screen-local, ephemeral UI state, same reasoning and shape as
/// [EditSelection] — plain `autoDispose`, cleared by
/// `timeline_screen.dart`'s own `ref.listen` wiring whenever Edit Mode
/// exits or multi-task mode toggles off, same as that provider.

@ProviderFor(ZoneEditSelection)
final zoneEditSelectionProvider = ZoneEditSelectionProvider._();

/// The set of ZONE ids currently selected under Edit Mode's multi-task
/// route — a separate provider from [EditSelection] (which holds TASK ids)
/// rather than one shared set, since the two are genuinely different
/// selections with no shared meaning (a task and a zone can never occupy
/// the same "selected" concept, and mixing their ids in one `Set<String>`
/// would make membership checks ambiguous about which kind of thing is
/// selected). **New 2026-09-06** (confirmed directly — zones should not
/// wiggle/be draggable in multi-task mode unless selected, mirroring the
/// existing task rule exactly): with multi-task mode on, tapping a zone's
/// header selects it instead of starting a move-drag, and wiggle becomes
/// the SELECTION indicator for zones too (only the selected zone wiggles)
/// rather than the mode indicator every zone shows under ordinary
/// (single-task) Edit Mode.
///
/// **Widened to genuine multi-select 2026-09-12** (was `String?`,
/// single-select). The original shape was justified by "there is no
/// group-zone-move feature" — that is no longer true: the Weekly Zone
/// Authoring Grid (`features/zone_grid/`) selects several zones at once
/// and moves/resizes them as a group, so this now mirrors
/// [EditSelection]'s `Set<String>` shape exactly.
///
/// Still a SEPARATE provider from [EditSelection] rather than one shared
/// set — that reasoning is unchanged and unrelated to cardinality: a task
/// id and a zone id have no shared meaning, and mixing them would make
/// membership checks ambiguous about which kind of thing is selected.
///
/// The Timeline's own zone selection (`_DraggableZoneBlock`) remains
/// effectively single-select in practice, because nothing there offers a
/// group gesture — it simply reads membership instead of equality now.
/// Screen-local, ephemeral UI state, same reasoning and shape as
/// [EditSelection] — plain `autoDispose`, cleared by
/// `timeline_screen.dart`'s own `ref.listen` wiring whenever Edit Mode
/// exits or multi-task mode toggles off, same as that provider.
final class ZoneEditSelectionProvider
    extends $NotifierProvider<ZoneEditSelection, Set<String>> {
  /// The set of ZONE ids currently selected under Edit Mode's multi-task
  /// route — a separate provider from [EditSelection] (which holds TASK ids)
  /// rather than one shared set, since the two are genuinely different
  /// selections with no shared meaning (a task and a zone can never occupy
  /// the same "selected" concept, and mixing their ids in one `Set<String>`
  /// would make membership checks ambiguous about which kind of thing is
  /// selected). **New 2026-09-06** (confirmed directly — zones should not
  /// wiggle/be draggable in multi-task mode unless selected, mirroring the
  /// existing task rule exactly): with multi-task mode on, tapping a zone's
  /// header selects it instead of starting a move-drag, and wiggle becomes
  /// the SELECTION indicator for zones too (only the selected zone wiggles)
  /// rather than the mode indicator every zone shows under ordinary
  /// (single-task) Edit Mode.
  ///
  /// **Widened to genuine multi-select 2026-09-12** (was `String?`,
  /// single-select). The original shape was justified by "there is no
  /// group-zone-move feature" — that is no longer true: the Weekly Zone
  /// Authoring Grid (`features/zone_grid/`) selects several zones at once
  /// and moves/resizes them as a group, so this now mirrors
  /// [EditSelection]'s `Set<String>` shape exactly.
  ///
  /// Still a SEPARATE provider from [EditSelection] rather than one shared
  /// set — that reasoning is unchanged and unrelated to cardinality: a task
  /// id and a zone id have no shared meaning, and mixing them would make
  /// membership checks ambiguous about which kind of thing is selected.
  ///
  /// The Timeline's own zone selection (`_DraggableZoneBlock`) remains
  /// effectively single-select in practice, because nothing there offers a
  /// group gesture — it simply reads membership instead of equality now.
  /// Screen-local, ephemeral UI state, same reasoning and shape as
  /// [EditSelection] — plain `autoDispose`, cleared by
  /// `timeline_screen.dart`'s own `ref.listen` wiring whenever Edit Mode
  /// exits or multi-task mode toggles off, same as that provider.
  ZoneEditSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneEditSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneEditSelectionHash();

  @$internal
  @override
  ZoneEditSelection create() => ZoneEditSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$zoneEditSelectionHash() => r'9311b33740fc9bd0fad06300a56bad5c06ac45a9';

/// The set of ZONE ids currently selected under Edit Mode's multi-task
/// route — a separate provider from [EditSelection] (which holds TASK ids)
/// rather than one shared set, since the two are genuinely different
/// selections with no shared meaning (a task and a zone can never occupy
/// the same "selected" concept, and mixing their ids in one `Set<String>`
/// would make membership checks ambiguous about which kind of thing is
/// selected). **New 2026-09-06** (confirmed directly — zones should not
/// wiggle/be draggable in multi-task mode unless selected, mirroring the
/// existing task rule exactly): with multi-task mode on, tapping a zone's
/// header selects it instead of starting a move-drag, and wiggle becomes
/// the SELECTION indicator for zones too (only the selected zone wiggles)
/// rather than the mode indicator every zone shows under ordinary
/// (single-task) Edit Mode.
///
/// **Widened to genuine multi-select 2026-09-12** (was `String?`,
/// single-select). The original shape was justified by "there is no
/// group-zone-move feature" — that is no longer true: the Weekly Zone
/// Authoring Grid (`features/zone_grid/`) selects several zones at once
/// and moves/resizes them as a group, so this now mirrors
/// [EditSelection]'s `Set<String>` shape exactly.
///
/// Still a SEPARATE provider from [EditSelection] rather than one shared
/// set — that reasoning is unchanged and unrelated to cardinality: a task
/// id and a zone id have no shared meaning, and mixing them would make
/// membership checks ambiguous about which kind of thing is selected.
///
/// The Timeline's own zone selection (`_DraggableZoneBlock`) remains
/// effectively single-select in practice, because nothing there offers a
/// group gesture — it simply reads membership instead of equality now.
/// Screen-local, ephemeral UI state, same reasoning and shape as
/// [EditSelection] — plain `autoDispose`, cleared by
/// `timeline_screen.dart`'s own `ref.listen` wiring whenever Edit Mode
/// exits or multi-task mode toggles off, same as that provider.

abstract class _$ZoneEditSelection extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Ephemeral, screen-local — mirrors [EditSelection]'s own reasoning
/// exactly. `autoDispose` is correct here specifically because this value
/// is only ever meaningful for the lifetime of one finger-down gesture;
/// there is no case where it should survive a rebuild of the Timeline
/// itself.

@ProviderFor(EditGroupGestureState)
final editGroupGestureStateProvider = EditGroupGestureStateProvider._();

/// Ephemeral, screen-local — mirrors [EditSelection]'s own reasoning
/// exactly. `autoDispose` is correct here specifically because this value
/// is only ever meaningful for the lifetime of one finger-down gesture;
/// there is no case where it should survive a rebuild of the Timeline
/// itself.
final class EditGroupGestureStateProvider
    extends $NotifierProvider<EditGroupGestureState, EditGroupGesture?> {
  /// Ephemeral, screen-local — mirrors [EditSelection]'s own reasoning
  /// exactly. `autoDispose` is correct here specifically because this value
  /// is only ever meaningful for the lifetime of one finger-down gesture;
  /// there is no case where it should survive a rebuild of the Timeline
  /// itself.
  EditGroupGestureStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editGroupGestureStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editGroupGestureStateHash();

  @$internal
  @override
  EditGroupGestureState create() => EditGroupGestureState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditGroupGesture? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditGroupGesture?>(value),
    );
  }
}

String _$editGroupGestureStateHash() =>
    r'4a87e98bd8e5aeba85d9c350c8846a45c4b249c5';

/// Ephemeral, screen-local — mirrors [EditSelection]'s own reasoning
/// exactly. `autoDispose` is correct here specifically because this value
/// is only ever meaningful for the lifetime of one finger-down gesture;
/// there is no case where it should survive a rebuild of the Timeline
/// itself.

abstract class _$EditGroupGestureState extends $Notifier<EditGroupGesture?> {
  EditGroupGesture? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditGroupGesture?, EditGroupGesture?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EditGroupGesture?, EditGroupGesture?>,
              EditGroupGesture?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
