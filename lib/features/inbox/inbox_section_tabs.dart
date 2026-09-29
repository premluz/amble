import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_context_menu.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_sub_nav.dart';
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
/// **2026-09-29 — the main nav's own labels, as a sub nav.** Requested
/// directly: the Inbox tabs should share the main nav's styling (text
/// labels, bold when selected) and sit exactly where the Day date and the
/// Habits period heading sit, so moving between those pages the heading
/// text doesn't budge. Built on [AppSubNav]; it replaced separated
/// `AppSelectableChip` pills (2026-09-21), which had replaced a segmented
/// `AppTabSwitch`.
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

    // The main nav's own labels, in the page-heading slot where the Day
    // date and Habits period sit — so switching pages, this line of text
    // doesn't move (requested directly).
    return AppSubNav(
      trailing: _CreateSectionButton(theme: theme),
      children: [
        _SectionTab(
          tabKey: targets.keys[all],
          label: 'All',
          selected: selected == all,
          isDropTarget: false,
          onTap: () => notifier.select(all),
        ),
        for (final section in sections)
          _SectionTab(
            tabKey: targets.keys[InboxSectionFilterSection(section.id)],
            label: section.name,
            selected: selected == InboxSectionFilterSection(section.id),
            isDropTarget:
                dropTargetFilter == InboxSectionFilterSection(section.id),
            onTap: () => notifier.select(InboxSectionFilterSection(section.id)),
            menuActions: _sectionTabMenuActions(context, ref, section),
          ),
        _SectionTab(
          tabKey: targets.keys[unfiled],
          label: 'Unfiled',
          selected: selected == unfiled,
          isDropTarget: dropTargetFilter == unfiled,
          onTap: () => notifier.select(unfiled),
        ),
      ],
    );
  }
}

List<AppContextMenuAction> _sectionTabMenuActions(
  BuildContext context,
  WidgetRef ref,
  Section section,
) {
  return [
    AppContextMenuAction(
      icon: Icons.edit_outlined,
      label: 'Rename',
      onTap: () => showRenameSectionSheet(context, section),
    ),
    AppContextMenuAction(
      icon: Icons.delete_outline_rounded,
      label: 'Remove',
      isDestructive: true,
      onTap: () => _removeSectionWithUndo(context, ref, section),
    ),
  ];
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

/// One tab — an [AppSubNavLabel], plus a drop-target wash while a row is
/// dragged over it. Drag-and-drop awareness stays here, specific to this
/// one Inbox use.
///
/// **2026-09-23 — two ways into the Rename/Remove menu, both faster than
/// Flutter's stock 500ms long-press.** Requested directly: "selected tab
/// should also allow opening dropdown / dropdown should open more quickly
/// too, long gap in long press / long press > popover shows > move finger
/// on edit > hover state > release = tap."
///
/// - A **long-press**, wrapped via [AppLongPressContextMenu] — owns the
///   whole press → move → release gesture itself so a finger that stays
///   down after the menu opens can drag onto a row (live highlight) and
///   release to select it, the seamless interaction that entry's own doc
///   comment covers in full.
/// - A **plain tap on an ALREADY-selected tab** (previously a pure no-op —
///   `select` on the filter it's already showing) — opens the same menu
///   via [AppContextMenu.showAt] instead. This path has no "still-down
///   finger to drag" to preserve (the label's tap fires on release, not
///   press), so it uses the route-based opener rather than
///   [AppLongPressContextMenu]'s own overlay.
class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.isDropTarget,
    required this.onTap,
    this.menuActions,
  });

  /// Measured by [InboxSectionTabTargets] to tell which tab a dragged row
  /// is over.
  final GlobalKey? tabKey;
  final String label;
  final bool selected;

  /// A row is being dragged over this tab: a wash shows behind it.
  final bool isDropTarget;
  final VoidCallback onTap;

  /// Rename/remove for a user section — from a tap on the SELECTED tab, or
  /// a long-press.
  final List<AppContextMenuAction>? menuActions;

  @override
  Widget build(BuildContext context) {
    Offset? lastPointerPosition;

    final tab = Listener(
      key: tabKey,
      onPointerDown: (event) => lastPointerPosition = event.position,
      child: AppSubNavLabel(
        label: label,
        selected: selected,
        highlighted: isDropTarget,
        onTap: () {
          final actions = menuActions;
          if (selected && actions != null && lastPointerPosition != null) {
            AppContextMenu.showAt(
              context,
              position: lastPointerPosition!,
              actions: actions,
            );
          } else {
            onTap();
          }
        },
      ),
    );

    return menuActions == null
        ? tab
        : AppLongPressContextMenu(actions: menuActions!, child: tab);
  }
}

/// "New section": a quiet "+" on the heading line — no taller than the
/// labels, so it never moves them.
class _CreateSectionButton extends StatelessWidget {
  const _CreateSectionButton({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New section',
      child: AppPressFeedback(
        onTap: () => showNewSectionSheet(context),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        child: Icon(
          Icons.add_rounded,
          size: theme.spacingMd,
          color: theme.colorTextTertiary,
        ),
      ),
    );
  }
}
