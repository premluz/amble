import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_motion.dart';

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

  Widget _surface() => Container(
    decoration: BoxDecoration(
      color: theme.colorSurfaceOverlay,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(theme.radiusModal),
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: SafeArea(top: false, child: Builder(builder: builder)),
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
