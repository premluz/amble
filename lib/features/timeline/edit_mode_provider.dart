import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'edit_mode_provider.g.dart';

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
@riverpod
class EditModeEnabled extends _$EditModeEnabled {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
