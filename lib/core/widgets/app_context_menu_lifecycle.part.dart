part of 'app_context_menu.dart';

class _AppContextMenuLifecycle {
  static final Map<Object, VoidCallback> _dismissers = {};

  static Object register(VoidCallback dismiss) {
    final token = Object();
    _dismissers[token] = dismiss;
    return token;
  }

  static void unregister(Object token) => _dismissers.remove(token);

  static void dismissOpenMenus() {
    for (final dismiss in _dismissers.values.toList()) {
      dismiss();
    }
  }

  static void dismissOpenMenusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissOpenMenus());
  }

  static Future<void> showAt(
    BuildContext context, {
    required Offset position,
    required List<AppContextMenuAction> actions,
  }) async {
    dismissOpenMenus();
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = _AnchoredContextMenuRoute(anchor: position, actions: actions);
    final token = register(() {
      if (!route.isDismissed && route.isActive) {
        route.markDismissed();
        navigator.removeRoute(route);
      }
    });
    try {
      await navigator.push<void>(route);
    } finally {
      unregister(token);
    }
  }
}

/// Closes floating context menus when a route changes without a corresponding
/// [AppViewTransition] update (for example, a pushed settings detail page).
class AppContextMenuNavigatorObserver extends NavigatorObserver {
  void _dismissAfterRouteChange() {
    _AppContextMenuLifecycle.dismissOpenMenusAfterFrame();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! _AnchoredContextMenuRoute) _dismissAfterRouteChange();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is _AnchoredContextMenuRoute) {
      route.markDismissed();
    } else {
      _dismissAfterRouteChange();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is _AnchoredContextMenuRoute) {
      route.markDismissed();
    } else {
      _dismissAfterRouteChange();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is! _AnchoredContextMenuRoute) _dismissAfterRouteChange();
  }
}
