part of 'app_context_menu.dart';

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
  bool _isDismissed = false;

  bool get isDismissed => _isDismissed;

  void markDismissed() => _isDismissed = true;

  /// Fast, not zero — [AppSheet]'s own sheets are zero-duration by
  /// explicit design ("remove animation completely for switching views"),
  /// but a small anchored popover reads as a distinct, lighter-weight
  /// interaction; it uses the app's shared fast/instant duration rungs
  /// instead of introducing context-menu-only timing values.
  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: MotionPrimitives.durationFastMs);

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: MotionPrimitives.durationInstantMs);

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
      onDismiss: markDismissed,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child; // The content drives its own entrance and exit — see below.
}

class _AnchoredContextMenuContent extends StatelessWidget {
  const _AnchoredContextMenuContent({
    required this.anchor,
    required this.actions,
    required this.animation,
    required this.onDismiss,
  });

  final Offset anchor;
  final List<AppContextMenuAction> actions;
  final Animation<double> animation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final geometry = _MenuGeometry.resolve(context, theme, anchor, actions);

    return GestureDetector(
      // Tapping anywhere outside the panel dismisses it — the panel's own
      // Material below stops this from also swallowing taps ON it.
      onTap: () {
        onDismiss();
        Navigator.of(context).maybePop();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: geometry.left,
            top: geometry.top,
            width: geometry.width,
            height: geometry.height,
            // Entrance is the liquid morph from the touch point; the route's
            // own animation only drives a quick fade on the way out.
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Opacity(
                opacity: animation.status == AnimationStatus.reverse
                    ? animation.value
                    : 1,
                child: child,
              ),
              child: AppLiquidMorph(
                origin: anchor - Offset(geometry.left, geometry.top),
                borderRadius: theme.radiusXxl,
                child: GestureDetector(
                  // Swallows the outer dismiss-on-tap for taps ON the panel
                  // itself — the panel's own rows still get their taps via
                  // ActionRow's own GestureDetector underneath this one.
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: _GlassMenuPanel(
                    theme: theme,
                    actions: actions,
                    maxHeight: geometry.height,
                    onActionTap: (action) {
                      onDismiss();
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
