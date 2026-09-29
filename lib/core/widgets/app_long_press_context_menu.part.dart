part of 'app_context_menu.dart';

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
  Object? _dismissalToken;
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
    AppContextMenu.dismissOpenMenus();
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
    _dismissalToken = _AppContextMenuLifecycle.register(_removeOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _removeOverlay() {
    final token = _dismissalToken;
    if (token != null) {
      _AppContextMenuLifecycle.unregister(token);
      _dismissalToken = null;
    }
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
/// externally-owned [hovered] notifier. It enters with the same
/// [AppLiquidMorph] as the tap popover, growing from the pressed point; the
/// morph owns its own springs, so an [OverlayEntry] needs no route animation.
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
      width: geometry.width,
      height: geometry.height,
      child: AppLiquidMorph(
        origin: anchor - Offset(geometry.left, geometry.top),
        borderRadius: theme.radiusXxl,
        child: ValueListenableBuilder<int?>(
          valueListenable: hovered,
          builder: (context, highlightedIndex, _) => _GlassMenuPanel(
            theme: theme,
            actions: actions,
            maxHeight: geometry.height,
            rowKeys: rowKeys,
            highlightedIndex: highlightedIndex,
            onActionTap: onActionTap,
          ),
        ),
      ),
    );
  }
}
