import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet.dart';
import 'app_floating_surface.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final geometry = _MenuGeometry.resolve(context, theme, anchor, actions);

    return GestureDetector(
      // Tapping anywhere outside the panel dismisses it — the panel's own
      // Material below stops this from also swallowing taps ON it.
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: geometry.left,
            top: geometry.top,
            width: _MenuGeometry.panelWidth,
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
                  child: _GlassMenuPanel(
                    theme: theme,
                    actions: actions,
                    onActionTap: (action) {
                      Navigator.of(context).pop();
                      action.onTap();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared position/size math for the popover panel — used by both
/// [_AnchoredContextMenuContent] (the tap-to-open route) and
/// [AppLongPressContextMenu] (the press-drag-release overlay), so the two
/// entry points place and size the panel identically.
class _MenuGeometry {
  const _MenuGeometry({required this.left, required this.top});

  final double left;
  final double top;

  static const panelWidth = 200.0;

  /// How far the panel's own top-left sits from the anchor — enough that
  /// the panel doesn't render directly under the pressing finger.
  static const _anchorOffset = Offset(-8, 8);

  static double rowHeight(AmbleTheme theme) => kMinInteractiveDimension;

  static double panelHeight(AmbleTheme theme, int actionCount) =>
      actionCount * rowHeight(theme) + theme.spacingSm * 2;

  /// Clamped so the panel never renders partly off-screen — a long
  /// Section-tab name near the right edge, or a press near the bottom nav,
  /// would otherwise push the panel past the viewport.
  static _MenuGeometry resolve(
    BuildContext context,
    AmbleTheme theme,
    Offset anchor,
    List<AppContextMenuAction> actions,
  ) {
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final height = panelHeight(theme, actions.length);

    var left = anchor.dx + _anchorOffset.dx;
    var top = anchor.dy + _anchorOffset.dy;
    left = left.clamp(
      theme.spacingSm,
      screenSize.width - panelWidth - theme.spacingSm,
    );
    top = top.clamp(
      safePadding.top + theme.spacingSm,
      screenSize.height - safePadding.bottom - height - theme.spacingSm,
    );
    return _MenuGeometry(left: left, top: top);
  }
}

/// Shared elevated glass; highlighting preserves the press-drag menu behavior.
class _GlassMenuPanel extends StatelessWidget {
  const _GlassMenuPanel({
    required this.theme,
    required this.actions,
    required this.onActionTap,
    this.highlightedIndex,
    this.rowKeys,
  });

  final AmbleTheme theme;
  final List<AppContextMenuAction> actions;
  final ValueChanged<AppContextMenuAction> onActionTap;
  final int? highlightedIndex;

  /// One [GlobalKey] per row, supplied by [AppLongPressContextMenu] so it
  /// can hit-test a live drag against each row's real on-screen bounds —
  /// null for [AppContextMenu.showAt], which has no drag to hit-test.
  final List<GlobalKey>? rowKeys;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.radiusModal);
    return AppFloatingSurface(
      theme: theme,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++)
                _MenuRow(
                  key: rowKeys?[i],
                  theme: theme,
                  action: actions[i],
                  highlighted: highlightedIndex == i,
                  onTap: () => onActionTap(actions[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row's own hover-highlight wrapper around [ActionRow] — a plain
/// `colorTextPrimary`-tinted wash, the same "subtle neutral tint" token
/// [AppButton.subtleTint] already names, so a hovered row reads as "about
/// to be pressed" the same way [AppPressFeedback]'s own ripple would, even
/// though a live drag-hover has no ripple animation of its own to play.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.theme,
    required this.action,
    required this.highlighted,
    required this.onTap,
  });

  final AmbleTheme theme;
  final AppContextMenuAction action;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorTextPrimary.withValues(alpha: 0.1)
            : null,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
        child: ActionRow(
          theme: theme,
          icon: action.icon,
          label: action.label,
          color: action.isDestructive ? theme.colorDestructive : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Wraps [child] with a long-press that opens the anchored glass popover
/// ([AppContextMenu.showAt]'s same visuals) and keeps tracking the SAME
/// press for a seamless "long-press, then drag onto an item while still
/// down, release to select" interaction — the standard iOS/Slack
/// context-menu gesture. Requested directly: "long press > popover shows >
/// move finger on edit > hover state > release = tap."
///
/// **Why not [AppContextMenu.showAt]:** that entry point pushes a real
/// `Navigator` route, whose own gesture arena can't receive move/end
/// events from a pointer a DIFFERENT widget's `GestureDetector` already
/// owns — once the route opens mid-gesture, the original finger's
/// movement/release just falls through with nothing listening. This widget
/// instead keeps the ENTIRE gesture (start → move → end) in one
/// [GestureDetector], inserts the menu as a plain [OverlayEntry] rather
/// than a route (so nothing new claims the pointer), and hit-tests the
/// live drag position against each row's own [GlobalKey] bounds —
/// mirroring `inbox_screen.dart`'s own `_DraggableInboxRow`
/// (`onLongPressMoveUpdate` → `targets.hitTest` → `onLongPressEnd`
/// resolves), the established pattern in this codebase for exactly this
/// shape of gesture, just adapted to a menu rather than a drop target.
class AppLongPressContextMenu extends StatefulWidget {
  const AppLongPressContextMenu({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<AppContextMenuAction> actions;
  final Widget child;

  /// Shorter than [kLongPressTimeout] (500ms) — reported directly as too
  /// slow a gap before the menu appeared.
  static const triggerDuration = Duration(milliseconds: 280);

  @override
  State<AppLongPressContextMenu> createState() =>
      _AppLongPressContextMenuState();
}

class _AppLongPressContextMenuState extends State<AppLongPressContextMenu> {
  OverlayEntry? _entry;
  final _rowKeys = <GlobalKey>[];

  /// Which row (by index into [AppLongPressContextMenu.actions]) the drag
  /// currently sits over, or null. A [ValueNotifier] rather than `setState`
  /// on this widget itself — only the overlay's own content needs to
  /// rebuild on hover change, not [widget.child] underneath it.
  final _hovered = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _removeOverlay();
    _hovered.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _rowKeys
      ..clear()
      ..addAll(List.generate(widget.actions.length, (_) => GlobalKey()));
    _hovered.value = null;
    _insertOverlay(details.globalPosition);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _hovered.value = _hitTestRow(details.globalPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final index = _hitTestRow(details.globalPosition);
    _removeOverlay();
    if (index != null) widget.actions[index].onTap();
  }

  void _onLongPressCancel() => _removeOverlay();

  int? _hitTestRow(Offset globalPosition) {
    for (var i = 0; i < _rowKeys.length; i++) {
      final renderObject = _rowKeys[i].currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      if ((topLeft & renderObject.size).contains(globalPosition)) return i;
    }
    return null;
  }

  void _insertOverlay(Offset anchor) {
    _entry = OverlayEntry(
      builder: (context) => _LiveAnchoredMenu(
        anchor: anchor,
        actions: widget.actions,
        rowKeys: _rowKeys,
        hovered: _hovered,
        // Tapping a row directly (finger lifted and re-tapped, rather
        // than dragged-then-released in one motion) still works — the
        // overlay isn't a route, so nothing auto-pops it on tap; this
        // closes it explicitly first.
        onActionTap: (action) {
          _removeOverlay();
          action.onTap();
        },
        onDismiss: _removeOverlay,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: widget.child,
    );
  }
}

/// The overlay content for [AppLongPressContextMenu] — the same
/// [_GlassMenuPanel] visuals [AppContextMenu.showAt] uses, but driven by an
/// externally-owned [hovered] notifier instead of the route's own
/// animation, and with no entrance transition (an [OverlayEntry] has no
/// animation controller of its own the way a [PopupRoute] does; the menu
/// simply appears the instant the long-press fires, which reads as
/// instantaneous rather than needing a fade-in of its own for this
/// particular interaction).
class _LiveAnchoredMenu extends StatelessWidget {
  const _LiveAnchoredMenu({
    required this.anchor,
    required this.actions,
    required this.rowKeys,
    required this.hovered,
    required this.onActionTap,
    required this.onDismiss,
  });

  final Offset anchor;
  final List<AppContextMenuAction> actions;
  final List<GlobalKey> rowKeys;
  final ValueNotifier<int?> hovered;
  final ValueChanged<AppContextMenuAction> onActionTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final geometry = _MenuGeometry.resolve(context, theme, anchor, actions);

    return Positioned(
      left: geometry.left,
      top: geometry.top,
      width: _MenuGeometry.panelWidth,
      child: ValueListenableBuilder<int?>(
        valueListenable: hovered,
        builder: (context, highlightedIndex, _) => _GlassMenuPanel(
          theme: theme,
          actions: actions,
          rowKeys: rowKeys,
          highlightedIndex: highlightedIndex,
          onActionTap: onActionTap,
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
