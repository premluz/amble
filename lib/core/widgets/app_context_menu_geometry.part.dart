part of 'app_context_menu.dart';

/// Shared position/size math for the popover panel — used by both
/// [_AnchoredContextMenuContent] (the tap-to-open route) and
/// [AppLongPressContextMenu] (the press-drag-release overlay), so the two
/// entry points place and size the panel identically.
class _MenuGeometry {
  const _MenuGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.opensAbove,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final bool opensAbove;

  static const panelWidth = 200.0;

  static double rowHeight(AmbleTheme theme) => kMinInteractiveDimension;

  static double panelHeight(AmbleTheme theme, int actionCount) =>
      actionCount * rowHeight(theme) + theme.spacingXs * 2;

  /// Prefers the side with enough room, then the side with more room. The
  /// final clamp is only a fallback for a menu taller than either side.
  static _MenuGeometry resolve(
    BuildContext context,
    AmbleTheme theme,
    Offset anchor,
    List<AppContextMenuAction> actions,
  ) {
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final horizontalInset = theme.spacingSm;
    final topInset = safePadding.top + theme.spacingSm;
    final proposedBottomInset =
        screenSize.height -
        math.max(safePadding.bottom, viewInsets.bottom) -
        theme.spacingSm;
    final bottomInset = math.max(topInset, proposedBottomInset);
    final leftInset = safePadding.left + horizontalInset;
    final rightInset = math.max(
      leftInset,
      screenSize.width - safePadding.right - horizontalInset,
    );
    final availableWidth = rightInset - leftInset;
    final width = math.min(panelWidth, availableWidth);
    final availableHeight = bottomInset - topInset;
    final height = math.min(
      panelHeight(theme, actions.length),
      availableHeight,
    );
    final anchorGap = theme.spacingSm;
    final spaceBelow = bottomInset - anchor.dy - anchorGap;
    final spaceAbove = anchor.dy - anchorGap - topInset;
    final opensAbove = spaceBelow < height && spaceAbove > spaceBelow;
    final proposedTop = opensAbove
        ? anchor.dy - anchorGap - height
        : anchor.dy + anchorGap;
    final maxLeft = rightInset - width;
    final maxTop = bottomInset - height;
    final left = (anchor.dx - width / 2).clamp(leftInset, maxLeft).toDouble();
    final top = proposedTop.clamp(topInset, maxTop).toDouble();

    return _MenuGeometry(
      left: left,
      top: top,
      width: width,
      height: height,
      opensAbove: opensAbove,
    );
  }
}
