part of 'app_context_menu.dart';

/// Shared elevated glass; highlighting preserves the press-drag menu behavior.
class _GlassMenuPanel extends StatelessWidget {
  const _GlassMenuPanel({
    required this.theme,
    required this.actions,
    required this.onActionTap,
    required this.maxHeight,
    this.highlightedIndex,
    this.rowKeys,
  });

  final AmbleTheme theme;
  final List<AppContextMenuAction> actions;
  final ValueChanged<AppContextMenuAction> onActionTap;
  final double maxHeight;
  final int? highlightedIndex;

  /// One [GlobalKey] per row, supplied by [AppLongPressContextMenu] so it
  /// can hit-test a live drag against each row's real on-screen bounds —
  /// null for [AppContextMenu.showAt], which has no drag to hit-test.
  final List<GlobalKey>? rowKeys;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.radiusXxl);
    return AppFloatingSurface(
      theme: theme,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    left: theme.spacingXs,
                    right: theme.spacingXs,
                    top:
                        _MenuGeometry.rowHeight(theme) *
                        (highlightedIndex ?? 0),
                    height: _MenuGeometry.rowHeight(theme),
                    duration: theme.motionFast,
                    curve: theme.curveDecelerate,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: highlightedIndex == null ? 0 : 1,
                        duration: theme.motionFast,
                        curve: theme.curveDecelerate,
                        child: DecoratedBox(
                          key: const ValueKey('context-menu-hover-pill'),
                          decoration: BoxDecoration(
                            color: theme.colorTextPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              theme.radiusPillFull,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++)
                        _MenuRow(
                          key: rowKeys?[i],
                          theme: theme,
                          action: actions[i],
                          onTap: () => onActionTap(actions[i]),
                        ),
                    ],
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
    required this.onTap,
  });

  final AmbleTheme theme;
  final AppContextMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
      child: ActionRow(
        theme: theme,
        icon: action.icon,
        label: action.label,
        color: action.isDestructive ? theme.colorDestructive : null,
        verticalPadding: theme.spacingIconTop,
        onTap: onTap,
      ),
    );
  }
}
