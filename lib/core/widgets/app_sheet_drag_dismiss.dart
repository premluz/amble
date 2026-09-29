import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_drag_to_close_handle.dart';

/// Drag a sheet down anywhere to close it — the iOS sheet gesture, on every
/// sheet rather than only those with a handle. The sheet follows the finger
/// down; past [SheetTokens.dragCloseDistance] (or on a fling) letting go
/// asks the route to pop, so a `PopScope` guarding unsaved work still
/// decides, and a refused close eases the sheet back. Content that scrolls
/// keeps its vertical drags while it has somewhere to scroll; pulled down
/// past its top, the pull moves the sheet instead, as on iOS. Scroll views
/// in a sheet clamp at their edges (no bounce), so that pull reaches the
/// sheet the same way on both platforms.
class AppSheetDragDismiss extends StatefulWidget {
  const AppSheetDragDismiss({
    super.key,
    required this.theme,
    required this.child,
  });

  final AmbleTheme theme;
  final Widget child;

  /// True while a drag is closing the sheet — an `AppSheetFlow` then lets
  /// the whole sheet go instead of stepping back one page, as on iOS.
  static bool isDismissing(BuildContext context) =>
      context
          .findAncestorStateOfType<_AppSheetDragDismissState>()
          ?._dismissing ??
      false;

  @override
  State<AppSheetDragDismiss> createState() => _AppSheetDragDismissState();
}

class _AppSheetDragDismissState extends State<AppSheetDragDismiss> {
  final _drag = AppDragToCloseController();

  /// A scroll view is being pulled past its top and moving the sheet.
  var _pulling = false;

  var _dismissing = false;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final route = ModalRoute.of(context);
    _dismissing = true;
    try {
      await Navigator.of(context).maybePop();
    } finally {
      _dismissing = false;
    }
    if (!mounted) return;
    if (route?.isCurrent ?? false) _drag.cancelClose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    switch (notification) {
      case OverscrollNotification(:final overscroll, :final dragDetails)
          when dragDetails != null && (overscroll < 0 || _pulling):
        _pulling = true;
        _drag.dragBy(-overscroll);
      case ScrollUpdateNotification(:final scrollDelta?, :final dragDetails)
          when _pulling && dragDetails != null && _drag.offset > 0:
        // Pushing back up first lowers the sheet to rest.
        _drag.dragBy(-scrollDelta);
      case ScrollEndNotification(:final dragDetails) when _pulling:
        _pulling = false;
        _drag.release(dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
      default:
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => AppDragToCloseHandle(
    theme: widget.theme,
    controller: _drag,
    closeDistance: SheetTokens.dragCloseDistance,
    onClose: _close,
    child: ListenableBuilder(
      listenable: _drag,
      child: _scrolling(widget.child),
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _drag.offset), child: child),
    ),
  );

  Widget _scrolling(Widget child) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context)
        .copyWith(physics: const ClampingScrollPhysics()),
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: child,
    ),
  );
}
