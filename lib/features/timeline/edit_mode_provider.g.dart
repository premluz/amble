// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the Timeline's Edit Mode is active — a toggleable direct-
/// manipulation mode (resize handles, drag-to-delete) per
/// CONSTITUTION.md's "Edit Mode" section.
///
/// Screen-local UI state, not app-level — lives under `features/timeline/`,
/// not `shared/providers/`, matching [SelectedDate]'s own precedent
/// (`selected_date_provider.dart`). Deliberately EPHEMERAL, not persisted
/// to Hive/`PreferencesRepository`: CONSTITUTION.md describes Edit Mode as
/// "a UI-layer toggle only, no new persisted state," and a returning user
/// should land on the ordinary Timeline, not silently reopen into edit
/// mode from wherever it was left. Plain `autoDispose` (the codegen
/// default), same as `SelectedDate` — it resets to `false` when the
/// Timeline itself is torn down, which is the desired behavior here, not
/// something to guard against with `keepAlive: true`.

@ProviderFor(EditModeEnabled)
final editModeEnabledProvider = EditModeEnabledProvider._();

/// Whether the Timeline's Edit Mode is active — a toggleable direct-
/// manipulation mode (resize handles, drag-to-delete) per
/// CONSTITUTION.md's "Edit Mode" section.
///
/// Screen-local UI state, not app-level — lives under `features/timeline/`,
/// not `shared/providers/`, matching [SelectedDate]'s own precedent
/// (`selected_date_provider.dart`). Deliberately EPHEMERAL, not persisted
/// to Hive/`PreferencesRepository`: CONSTITUTION.md describes Edit Mode as
/// "a UI-layer toggle only, no new persisted state," and a returning user
/// should land on the ordinary Timeline, not silently reopen into edit
/// mode from wherever it was left. Plain `autoDispose` (the codegen
/// default), same as `SelectedDate` — it resets to `false` when the
/// Timeline itself is torn down, which is the desired behavior here, not
/// something to guard against with `keepAlive: true`.
final class EditModeEnabledProvider
    extends $NotifierProvider<EditModeEnabled, bool> {
  /// Whether the Timeline's Edit Mode is active — a toggleable direct-
  /// manipulation mode (resize handles, drag-to-delete) per
  /// CONSTITUTION.md's "Edit Mode" section.
  ///
  /// Screen-local UI state, not app-level — lives under `features/timeline/`,
  /// not `shared/providers/`, matching [SelectedDate]'s own precedent
  /// (`selected_date_provider.dart`). Deliberately EPHEMERAL, not persisted
  /// to Hive/`PreferencesRepository`: CONSTITUTION.md describes Edit Mode as
  /// "a UI-layer toggle only, no new persisted state," and a returning user
  /// should land on the ordinary Timeline, not silently reopen into edit
  /// mode from wherever it was left. Plain `autoDispose` (the codegen
  /// default), same as `SelectedDate` — it resets to `false` when the
  /// Timeline itself is torn down, which is the desired behavior here, not
  /// something to guard against with `keepAlive: true`.
  EditModeEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editModeEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editModeEnabledHash();

  @$internal
  @override
  EditModeEnabled create() => EditModeEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$editModeEnabledHash() => r'f166da326273a9f0b3c7adfb4e376b4126d09e85';

/// Whether the Timeline's Edit Mode is active — a toggleable direct-
/// manipulation mode (resize handles, drag-to-delete) per
/// CONSTITUTION.md's "Edit Mode" section.
///
/// Screen-local UI state, not app-level — lives under `features/timeline/`,
/// not `shared/providers/`, matching [SelectedDate]'s own precedent
/// (`selected_date_provider.dart`). Deliberately EPHEMERAL, not persisted
/// to Hive/`PreferencesRepository`: CONSTITUTION.md describes Edit Mode as
/// "a UI-layer toggle only, no new persisted state," and a returning user
/// should land on the ordinary Timeline, not silently reopen into edit
/// mode from wherever it was left. Plain `autoDispose` (the codegen
/// default), same as `SelectedDate` — it resets to `false` when the
/// Timeline itself is torn down, which is the desired behavior here, not
/// something to guard against with `keepAlive: true`.

abstract class _$EditModeEnabled extends $Notifier<bool> {
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
