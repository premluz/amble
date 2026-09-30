import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_drag_dismiss.dart';
import 'app_sheet_motion.dart';
import 'app_sheet_surface.dart';

class AppSheetRoute<T> extends PopupRoute<T> {
  AppSheetRoute({
    required this.isCupertino,
    required this.autofocusesKeyboard,
    required this.theme,
    required this.builder,
  });

  final bool isCupertino;
  final bool autofocusesKeyboard;
  final AmbleTheme theme;
  final WidgetBuilder builder;

  @override
  Duration get transitionDuration =>
      autofocusesKeyboard ? theme.motionKeyboardSettle : theme.motionSheetSlide;

  @override
  Duration get reverseTransitionDuration => theme.motionSheetSlide;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Dismiss';

  @override
  Color get barrierColor =>
      isCupertino ? kCupertinoModalBarrierColor : theme.colorScrim;

  Widget _surface() => AppSheetDragDismiss(
    theme: theme,
    child: AppSheetSurface(
      theme: theme,
      child: Material(
        type: MaterialType.transparency,
        // The bottom safe area is inside the sheet's own scroll (see
        // `AppSheet.show`), so content can reach the phone's edge.
        child: SafeArea(
          top: false,
          bottom: false,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = AppSheetMotion(
      theme: theme,
      routeAnimation: animation,
      autofocusesKeyboard: autofocusesKeyboard,
      child: _surface(),
    );
    return isCupertino
        ? CupertinoUserInterfaceLevel(
            data: CupertinoUserInterfaceLevelData.elevated,
            child: page,
          )
        : page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
