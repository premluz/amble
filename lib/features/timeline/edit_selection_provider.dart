import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'edit_selection_provider.g.dart';

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
@riverpod
class EditSelection extends _$EditSelection {
  @override
  Set<String> build() => const {};

  void toggle(String taskId) {
    final next = Set<String>.of(state);
    if (!next.remove(taskId)) next.add(taskId);
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = const {};
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
/// Deliberately single-select only (toggling a new zone id REPLACES
/// whatever was selected, rather than adding to a set) — unlike
/// [EditSelection]'s genuine multi-select: there is no group-zone-move
/// feature (CONSTITUTION.md's multi-task route is "Tasks only, Zones
/// deferred to a follow-up round" for the GROUP-gesture machinery
/// specifically), so only ever one zone at a time can be the thing a drag
/// actually acts on. Screen-local, ephemeral UI state, same reasoning and
/// shape as [EditSelection] — plain `autoDispose`, cleared by
/// `timeline_screen.dart`'s own `ref.listen` wiring whenever Edit Mode
/// exits or multi-task mode toggles off, same as that provider.
@riverpod
class ZoneEditSelection extends _$ZoneEditSelection {
  @override
  String? build() => null;

  void toggle(String zoneId) => state = state == zoneId ? null : zoneId;

  void clear() {
    if (state == null) return;
    state = null;
  }
}

/// The kind of gesture a live [EditGroupGesture] broadcast describes —
/// needed because move and resize apply their delta completely
/// differently downstream (move shifts every selected block's position by
/// the same pixel offset; resize grows/shrinks every selected block's
/// pill height by the same duration delta), and a single untyped `double`
/// would leave every listener guessing which one is in flight.
/// Which axis a live group gesture is manipulating.
///
/// [resize] is the BOTTOM edge (duration only); [resizeTop] is the top
/// edge, which moves each task's start and compensates its duration so
/// every END stays anchored. They are separate kinds because a follower
/// block previews them differently — a bottom resize changes only the
/// block's height, a top resize changes its height AND its top edge.
enum EditGroupGestureKind { move, resize, resizeTop }

/// One selected task's move/resize delta, live while a group gesture is
/// in progress — the piece of state that makes group manipulation
/// possible at all. Every OTHER block's own per-block drag/resize state
/// ([_DraggableTaskBlockState]'s `_dragOffset`/`_resizeOffset`) lives
/// entirely inside that one block's State and is invisible to its
/// siblings; broadcasting the ACTIVELY-dragged block's own live offset
/// through this provider is what lets every OTHER selected block render
/// itself as "following" the drag without needing its own finger on
/// screen. Null whenever no group gesture is in flight — every selected
/// block that isn't the one actually being touched watches this and
/// renders unchanged while it's null.
class EditGroupGesture {
  const EditGroupGesture({required this.kind, required this.deltaPixels});

  final EditGroupGestureKind kind;

  /// Raw (unsnapped) pixel delta — a follower converts this to minutes
  /// using its OWN `pixelsPerMinute`, same as the actively-dragged block
  /// already does for itself, so every follower's snap math stays
  /// self-contained rather than trusting a value some other block already
  /// converted.
  final double deltaPixels;
}

/// Ephemeral, screen-local — mirrors [EditSelection]'s own reasoning
/// exactly. `autoDispose` is correct here specifically because this value
/// is only ever meaningful for the lifetime of one finger-down gesture;
/// there is no case where it should survive a rebuild of the Timeline
/// itself.
@riverpod
class EditGroupGestureState extends _$EditGroupGestureState {
  @override
  EditGroupGesture? build() => null;

  void update(EditGroupGesture? gesture) => state = gesture;
}
