import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_context_menu.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/section.dart';
import '../../shared/providers/section_providers.dart';
import 'inbox_section_filter_provider.dart';
import 'new_section_sheet.dart';

/// Whether [globalPosition] falls within [key]'s current on-screen bounds
/// — the same geometry `isInsideDeleteTarget`
/// (`timeline/edit_mode_delete_target.dart`) already establishes for a
/// single fixed target, generalized here to whichever tab a live drag is
/// currently checking against.
bool isGlobalPositionInsideKey(GlobalKey key, Offset globalPosition) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final bounds = topLeft & renderObject.size;
  return bounds.contains(globalPosition);
}

/// Owns one [GlobalKey] per rendered tab (All, Unfiled, one per real
/// [Section]) so a live Inbox-row drag (`_DraggableInboxRow` in
/// `inbox_screen.dart`) can hit-test its pointer position against every
/// tab's actual on-screen bounds — mirrors `EditModeDeleteTarget`'s own
/// single-`GlobalKey` drop-target pattern, just for N targets.
///
/// Rebuilt whenever the Section list changes (a fresh key per current
/// tab) — cheap, and simpler than diffing keys against ids, since this
/// only needs to be correct for the CURRENT frame's hit-testing, never
/// persisted across rebuilds.
class InboxSectionTabTargets {
  InboxSectionTabTargets(List<InboxSectionFilter> filters)
    : keys = {for (final filter in filters) filter: GlobalKey()};

  final Map<InboxSectionFilter, GlobalKey> keys;

  /// The filter whose tab bounds contain [globalPosition], or null if the
  /// point isn't over any tab — "All" is deliberately excluded from
  /// matching (see `_DraggableInboxRow.onLongPressEnd`'s own doc comment:
  /// dropping on "All" isn't a real assignment target).
  InboxSectionFilter? hitTest(Offset globalPosition) {
    for (final entry in keys.entries) {
      if (entry.key is InboxSectionFilterAll) continue;
      if (isGlobalPositionInsideKey(entry.value, globalPosition)) {
        return entry.key;
      }
    }
    return null;
  }
}

/// The pinned Section tab row at the top of the Inbox — "All" + one tab
/// per user-created [Section] + "Unfiled", plus a trailing "+" to create
/// a new one.
///
/// **2026-09-21 — separated pill buttons, not a segmented control.**
/// Requested directly: "Sections should be separated button tabs, not
/// segmented button." Reversed from the earlier `AppTabSwitch` version
/// (one shared recessed track, a sliding highlight) to [AppSelectableChip]
/// — each tab its own independently filled/unfilled pill with a real gap
/// between them, the same shape the Repeats day-of-week chips and the
/// Duration modal's presets already use. No shared-track-width problem to
/// solve here either: each chip already sizes to its own label, so a
/// plain `SingleChildScrollView` is enough — no need for `AppTabSwitch`'s
/// own fits-vs-scrolls measuring pass.
///
/// Fixed so it never scrolls away with the list underneath it (the
/// caller, `InboxScreen`, places this OUTSIDE the scrolling list's own
/// `Stack`).
class InboxSectionTabs extends ConsumerWidget {
  const InboxSectionTabs({
    super.key,
    required this.targets,
    this.dropTargetFilter,
  });

  /// Supplied by the caller (not created internally) so the SAME
  /// [GlobalKey]s this row renders with are the ones a live drag
  /// hit-tests against — see [InboxSectionTabTargets]'s own doc comment.
  final InboxSectionTabTargets targets;

  /// The tab a live Inbox-row drag is currently hovering, or null while
  /// no drag is in progress. Owned by `_DraggableInboxRow`'s own drag
  /// state, not by this row.
  final InboxSectionFilter? dropTargetFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final sections = ref.watch(sectionListProvider);
    final selected = ref.watch(inboxSectionFilterStateProvider);
    final notifier = ref.read(inboxSectionFilterStateProvider.notifier);

    const all = InboxSectionFilterAll();
    const unfiled = InboxSectionFilterUnfiled();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        theme.spacingSm,
        theme.spacingScreenPadding,
        theme.spacingSm,
      ),
      child: SizedBox(
        height: theme.sizeButtonMd,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SectionTabChip(
                      theme: theme,
                      chipKey: targets.keys[all],
                      label: 'All',
                      selected: selected == all,
                      isDropTarget: false,
                      onTap: () => notifier.select(all),
                    ),
                    for (final section in sections) ...[
                      SizedBox(width: theme.spacingXs),
                      _SectionTabChip(
                        theme: theme,
                        chipKey:
                            targets.keys[InboxSectionFilterSection(section.id)],
                        label: section.name,
                        selected:
                            selected == InboxSectionFilterSection(section.id),
                        isDropTarget:
                            dropTargetFilter ==
                            InboxSectionFilterSection(section.id),
                        onTap: () => notifier.select(
                          InboxSectionFilterSection(section.id),
                        ),
                        onOpenMenu: (position) => _showSectionTabMenu(
                          context,
                          ref,
                          section,
                          position,
                        ),
                      ),
                    ],
                    SizedBox(width: theme.spacingXs),
                    _SectionTabChip(
                      theme: theme,
                      chipKey: targets.keys[unfiled],
                      label: 'Unfiled',
                      selected: selected == unfiled,
                      isDropTarget: dropTargetFilter == unfiled,
                      onTap: () => notifier.select(unfiled),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: theme.spacingSm),
            _CreateSectionButton(theme: theme),
          ],
        ),
      ),
    );
  }
}

/// Opens the "Rename / Remove" context menu for one user-created [Section]
/// tab, triggered by long-pressing it — "All" and "Unfiled" are fixed,
/// non-Section filters (see `InboxSectionFilter`'s own subtypes) and never
/// get this menu, matching how they're already excluded from
/// [InboxSectionTabTargets.hitTest]'s drag-drop targeting for the same
/// reason: neither is a real, renameable/deletable [Section] row.
///
/// Presented via [AppContextMenu.showAt] — anchored at the long-press's own
/// position, rather than [AppContextMenu.show]'s bottom sheet (requested
/// directly: "a proper context menu that can open anywhere, not just
/// bottom sheet"). Same "Rename" / "Remove" (destructive, `colorTaskAlert`)
/// content shape `task_action_sheet.dart`'s own Task menu already
/// establishes — only the presentation differs here, not the actions.
Future<void> _showSectionTabMenu(
  BuildContext context,
  WidgetRef ref,
  Section section,
  Offset position,
) {
  return AppContextMenu.showAt(
    context,
    position: position,
    actions: [
      AppContextMenuAction(
        icon: Icons.edit_outlined,
        label: 'Rename',
        // No manual pop here, unlike a [show] (bottom sheet) caller —
        // [showAt]'s own menu route already pops itself before running
        // this callback (see [_ActionRowMenuEntryState]'s own doc
        // comment), so popping again here would incorrectly pop the
        // Inbox screen underneath instead.
        onTap: () => showRenameSectionSheet(context, section),
      ),
      AppContextMenuAction(
        icon: Icons.delete_outline_rounded,
        label: 'Remove',
        isDestructive: true,
        onTap: () => _removeSectionWithUndo(context, ref, section),
      ),
    ],
  );
}

/// Deletes [section] and shows an Undo toast — mirrors `removeTask`'s
/// (`task_detail/task_remove.dart`) and `zone_form_screen.dart`'s own
/// `_delete`'s "snapshot before delete, restore via a plain keyed re-save"
/// shape, and this app's established "Remove deletes immediately, no
/// confirmation dialog" convention (see those two sites' own doc comments)
/// rather than an `AppAlertDialog` confirm step.
///
/// Restoring a [Section] alone does not restore any [Task.sectionId] that
/// pointed to it — [SectionList.deleteSection] unassigns every affected
/// task's `sectionId` as a real, separate write (see its own doc comment:
/// "if a section is deleted, its items become unfiled"), which Undo here
/// does not attempt to reverse, matching how this codebase already accepts
/// that same asymmetry for `CategoryList.deleteCategory`'s reassign-to-
/// `general` side effect.
void _removeSectionWithUndo(
  BuildContext context,
  WidgetRef ref,
  Section section,
) {
  final notifier = ref.read(sectionListProvider.notifier);
  final snapshot = section.toJson();
  notifier.deleteSection(section.id);
  AppUndoToast.show(
    context: context,
    message: "Removed '${section.name}'",
    onUndo: () => notifier.restoreSection(Section.fromJson(snapshot)),
  );
}

/// One tab — [AppSelectableChip]'s own selected/unselected fill, plus an
/// optional drop-target border overlay. Not folded into
/// [AppSelectableChip] itself: drag-and-drop awareness is specific to
/// this one Inbox use, and that shared component otherwise has no notion
/// of a live drag hovering it.
///
/// **2026-09-23 — tapping an ALREADY-selected tab also opens the menu, and
/// the long-press that opens it fires sooner than Flutter's stock 500ms.**
/// Requested directly: "selected tab should also allow opening dropdown /
/// dropdown should open more quickly too, long gap in long press." A tap
/// on a selected tab was previously a pure no-op (`select` on the filter
/// it's already showing) — now it opens [onOpenMenu] instead, so there are
/// two ways in rather than long-press being the only one. The long-press
/// itself uses a custom [LongPressGestureRecognizer] with
/// [_menuLongPressDuration] via [RawGestureDetector], since plain
/// [GestureDetector] has no parameter for the recognizer's own trigger
/// delay — only [AppButton]-style tap timing.
class _SectionTabChip extends StatelessWidget {
  const _SectionTabChip({
    required this.theme,
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.isDropTarget,
    required this.onTap,
    this.onOpenMenu,
  });

  final AmbleTheme theme;
  final GlobalKey? chipKey;
  final String label;
  final bool selected;
  final bool isDropTarget;
  final VoidCallback onTap;

  /// Opens [_showSectionTabMenu] at the given press position — from either
  /// a long-press or a tap on an already-selected tab. Null for
  /// "All"/"Unfiled", which aren't real [Section] rows and have nothing to
  /// rename/remove.
  final ValueChanged<Offset>? onOpenMenu;

  /// Shorter than [kLongPressTimeout] (500ms) — reported directly as too
  /// slow a gap before the menu appeared. Still comfortably above a plain
  /// tap's own recognition window, so it doesn't start competing with
  /// ordinary taps or the drag-to-file gesture `_DraggableInboxRow` uses
  /// elsewhere in the Inbox (a different gesture surface — Inbox ROWS, not
  /// these Section TABS — so there's no actual collision here, just a
  /// margin kept for feel).
  static const _menuLongPressDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    Offset? lastPointerPosition;

    return RawGestureDetector(
      gestures: {
        if (onOpenMenu != null)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: _menuLongPressDuration,
                ),
                (instance) {
                  instance.onLongPressStart = (details) =>
                      onOpenMenu!(details.globalPosition);
                },
              ),
      },
      child: Listener(
        onPointerDown: (event) => lastPointerPosition = event.position,
        child: Stack(
          key: chipKey,
          clipBehavior: Clip.none,
          children: [
            AppSelectableChip(
              label: label,
              selected: selected,
              onTap: () {
                if (selected && onOpenMenu != null && lastPointerPosition != null) {
                  onOpenMenu!(lastPointerPosition!);
                } else {
                  onTap();
                }
              },
            ),
            // A 2px border over the resting fill, not a fill-color change —
            // the same `ZoneContainerBlock.isDropTarget` idiom used
            // elsewhere for "you're about to drop here" feedback.
            if (isDropTarget)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorTextPrimary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateSectionButton extends StatelessWidget {
  const _CreateSectionButton({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: theme.sizeButtonMd,
      width: theme.sizeButtonMd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.add_rounded, color: theme.colorTextSecondary),
          tooltip: 'New section',
          onPressed: () => showNewSectionSheet(context),
        ),
      ),
    );
  }
}
