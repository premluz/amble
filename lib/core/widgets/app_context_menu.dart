import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import 'app_sheet.dart';
import 'app_floating_surface.dart';
import 'app_liquid_morph.dart';

part 'app_context_menu_anchored.part.dart';
part 'app_context_menu_geometry.part.dart';
part 'app_context_menu_panel.part.dart';
part 'app_context_menu_lifecycle.part.dart';
part 'app_long_press_context_menu.part.dart';

/// One row's worth of intent for [AppContextMenu] — a label, an icon, and
/// what to do when tapped, optionally marked [isDestructive] for the same
/// `colorDestructive` treatment the app's existing delete/remove rows
/// already use (`task_action_sheet.dart`'s "Remove", `task_remove.dart`'s
/// own remove-scope rows).
class AppContextMenuAction {
  const AppContextMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// A bottom-sheet action menu — a short list of [AppContextMenuAction] rows,
/// one optionally destructive (styled red via `colorDestructive`). Promoted
/// from `task_action_sheet.dart`'s own Task menu (Edit/Mark
/// important/Duplicate/Remove) and `task_remove.dart`'s remove-scope sheet,
/// which had each hand-built the same `AppSheet` + `Column` of rows —
/// this is that shape made reusable, so a THIRD near-identical menu (the
/// Inbox Section tab's own long-press Rename/Remove) didn't become a
/// fourth hand-rolled copy.
///
/// Each [AppContextMenuAction.onTap] is responsible for popping the sheet
/// itself first if it needs the caller's own surviving context afterward
/// (same contract [ActionRow]'s own callers already followed) — this
/// widget does not auto-pop, since some callers (e.g. a rename that opens
/// a second sheet) need to pop before pushing the next route rather than
/// after.
class AppContextMenu extends StatelessWidget {
  const AppContextMenu({super.key, required this.actions});

  final List<AppContextMenuAction> actions;

  /// Closes every anchored menu and held-gesture menu before a page or view
  /// transition, and when another route takes over the app.
  static void dismissOpenMenus() => _AppContextMenuLifecycle.dismissOpenMenus();

  static void dismissOpenMenusAfterFrame() =>
      _AppContextMenuLifecycle.dismissOpenMenusAfterFrame();

  static Future<void> show(
    BuildContext context, {
    required List<AppContextMenuAction> actions,
  }) {
    return AppSheet.show<void>(
      context: context,
      builder: (sheetContext) => AppContextMenu(actions: actions),
    );
  }

  /// The anchored alternative to [show] — a small floating popover at
  /// [position] (screen coordinates, typically a long-press's own
  /// `globalPosition`) rather than a bottom sheet. Opt-in per call site —
  /// [show] (the bottom sheet) is unchanged and still the default for every
  /// existing caller; this is for a caller that specifically wants the
  /// menu to appear where the user pressed, not slide up from the bottom.
  ///
  /// **2026-09-23 — a custom [_AnchoredContextMenuRoute], not `showMenu`.**
  /// The original version used Flutter's `showMenu`, which wraps its
  /// content in an opaque `Material` — incompatible with a real
  /// `BackdropFilter` glass panel, since `Material`'s own paint sits
  /// between the content and whatever is behind it. Reported directly:
  /// "dropdown pane should style as per our design system (tokens) and
  /// rounding should be more, and bg should be glass." This route mirrors
  /// `AppSheet`'s own `_InstantCupertinoSheetRoute` precedent — a small,
  /// local `PopupRoute` built for exactly this one shape, rather than
  /// fighting a stock Flutter overlay's own opaque chrome. Same [ActionRow]
  /// content as [show]; only the presentation container differs.
  ///
  /// **Only for a menu opened WITHOUT a still-down finger** (e.g. the
  /// second open path added alongside [AppLongPressContextMenu]: tapping an
  /// already-selected Inbox Section tab). A route can't receive move/end
  /// events from a pointer a DIFFERENT widget's recognizer already owns —
  /// see [AppLongPressContextMenu]'s own doc comment for the seamless
  /// press-drag-release case this can't cover.
  static Future<void> showAt(
    BuildContext context, {
    required Offset position,
    required List<AppContextMenuAction> actions,
  }) => _AppContextMenuLifecycle.showAt(
    context,
    position: position,
    actions: actions,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        for (final action in actions)
          ActionRow(
            theme: theme,
            icon: action.icon,
            label: action.label,
            color: action.isDestructive ? theme.colorDestructive : null,
            onTap: action.onTap,
          ),
      ],
    );
  }
}

/// One row in an [AppContextMenu] — an icon, a label, and a tap target.
/// Promoted from `task_detail/task_remove.dart`, which originally defined
/// this alongside [removeTask]/[askRemoveScope] since those were its only
/// two callers; now a core primitive so any menu (not just Task-related
/// ones) can use the same row.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.verticalPadding,
  });

  final AmbleTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? theme.colorTextPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding ?? theme.spacingMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: rowColor),
            SizedBox(width: theme.spacingMd),
            // Expanded so a long label wraps/ellipsises instead of
            // overflowing the row — the original labels were all short
            // enough to fit, but the remove-scope sheet's longer ones
            // ("Remove this occurrence") pushed it 56px over, which a
            // widget test caught as a RenderFlex overflow.
            Expanded(
              child: Text(
                label,
                style: theme.textBody.copyWith(
                  color: rowColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
