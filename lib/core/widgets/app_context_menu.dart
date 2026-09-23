import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet.dart';

/// One row's worth of intent for [AppContextMenu] — a label, an icon, and
/// what to do when tapped, optionally marked [isDestructive] for the same
/// `colorTaskAlert` treatment the app's existing delete/remove rows already
/// use (`task_action_sheet.dart`'s "Remove", `task_remove.dart`'s own
/// remove-scope rows).
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
/// one optionally destructive (styled red via `colorTaskAlert`). Promoted
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
  static Future<void> showAt(
    BuildContext context, {
    required Offset position,
    required List<AppContextMenuAction> actions,
  }) {
    return Navigator.of(
      context,
    ).push(_AnchoredContextMenuRoute(anchor: position, actions: actions));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          ActionRow(
            theme: theme,
            icon: action.icon,
            label: action.label,
            color: action.isDestructive ? theme.colorTaskAlert : null,
            onTap: action.onTap,
          ),
      ],
    );
  }
}

/// The [PopupRoute] behind [AppContextMenu.showAt] — a small glass panel
/// positioned near [anchor], clamped to stay fully on screen. Mirrors
/// `AppSheet`'s own `_InstantCupertinoSheetRoute`: a local route built for
/// one specific presentation shape rather than reusing a stock Flutter
/// overlay whose chrome doesn't fit (see [AppContextMenu.showAt]'s own doc
/// comment for why `showMenu` was replaced).
class _AnchoredContextMenuRoute extends PopupRoute<void> {
  _AnchoredContextMenuRoute({required this.anchor, required this.actions});

  final Offset anchor;
  final List<AppContextMenuAction> actions;

  /// Fast, not zero — [AppSheet]'s own sheets are zero-duration by
  /// explicit design ("remove animation completely for switching views"),
  /// but a small anchored popover reads as a distinct, lighter-weight
  /// interaction; `theme.motionFast` (150ms, the app's own "fast" rung —
  /// see `MotionPrimitives.durationFastMs`) is used at the CALL site
  /// instead of a bespoke value here, so this stays consistent with every
  /// other "fast" transition in the app rather than inventing a new one.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Dismiss';

  // Transparent — this popover has no dimming scrim of its own (unlike a
  // full-screen sheet's barrierColor), since it's a small, local control
  // anchored near where the user was already looking, not a modal that
  // needs to pull focus away from the rest of the screen.
  @override
  Color get barrierColor => Colors.transparent;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _AnchoredContextMenuContent(
      anchor: anchor,
      actions: actions,
      animation: animation,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child; // The content widget drives its own fade/scale — see below.
}

class _AnchoredContextMenuContent extends StatelessWidget {
  const _AnchoredContextMenuContent({
    required this.anchor,
    required this.actions,
    required this.animation,
  });

  final Offset anchor;
  final List<AppContextMenuAction> actions;
  final Animation<double> animation;

  /// How far the panel's own top-left sits from [anchor] — enough that the
  /// panel doesn't render directly under the pressing finger.
  static const _anchorOffset = Offset(-8, 8);

  static const _panelWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);

    // Clamped so the panel never renders partly off-screen — a long
    // Section-tab name near the right edge, or a press near the bottom nav,
    // would otherwise push the panel past the viewport.
    final rowHeight = kMinInteractiveDimension;
    final panelHeight = actions.length * rowHeight + theme.spacingSm * 2;
    var left = anchor.dx + _anchorOffset.dx;
    var top = anchor.dy + _anchorOffset.dy;
    left = left.clamp(
      theme.spacingSm,
      screenSize.width - _panelWidth - theme.spacingSm,
    );
    top = top.clamp(
      safePadding.top + theme.spacingSm,
      screenSize.height - safePadding.bottom - panelHeight - theme.spacingSm,
    );

    return GestureDetector(
      // Tapping anywhere outside the panel dismisses it — the panel's own
      // Material below stops this from also swallowing taps ON it.
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: _panelWidth,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.92,
                  end: 1,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  // Swallows the outer dismiss-on-tap for taps ON the panel
                  // itself — the panel's own rows still get their taps via
                  // ActionRow's own GestureDetector underneath this one.
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: _GlassMenuPanel(theme: theme, actions: actions),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The popover's own surface — same glass recipe [GlassPillSurface] already
/// establishes (`colorTextPrimary` tinted at low alpha, `BackdropFilter` at
/// `blurOverlaySigma`, per its own doc comment on why NOT
/// `colorSurfaceBlurOverlay` directly), sized to `radiusXl` rather than
/// `radiusPill` — a menu panel is a rounded rectangle, not a pill, so it
/// borrows the same "more rounded" corner every modal sheet uses
/// (`theme.radiusModal`) instead of a fully-round shape that wouldn't suit
/// a multi-row list.
class _GlassMenuPanel extends StatelessWidget {
  const _GlassMenuPanel({required this.theme, required this.actions});

  final AmbleTheme theme;
  final List<AppContextMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.radiusModal);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.blurOverlaySigma,
          sigmaY: theme.blurOverlaySigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorTextPrimary.withValues(alpha: 0.16),
            borderRadius: radius,
            // A hairline edge reads better on glass than a shadow would —
            // matches how `AppSheet`'s own cards distinguish a translucent
            // surface from the blur behind it.
            border: Border.all(
              color: theme.colorTextPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in actions)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacingMd,
                      ),
                      child: ActionRow(
                        theme: theme,
                        icon: action.icon,
                        label: action.label,
                        color: action.isDestructive
                            ? theme.colorTaskAlert
                            : null,
                        // Pops the menu route FIRST, then runs the action —
                        // same pop-then-select order `showMenu`'s own
                        // PopupMenuItem used, kept here even though this is
                        // no longer built on PopupMenuItem.
                        onTap: () {
                          Navigator.of(context).pop();
                          action.onTap();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  });

  final AmbleTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? theme.colorTextPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingMd),
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
