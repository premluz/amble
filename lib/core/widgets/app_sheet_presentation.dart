import 'package:flutter/widgets.dart';

/// How [AppSheet.show] presents its content below this point in the tree.
enum AppSheetPresentation {
  /// Slides up from the bottom of the screen (phones, and anywhere without
  /// a scope).
  sheet,

  /// Opens as a floating popover beside the control that asked for it —
  /// the wide layout's side panel, where a bottom sheet would cover the
  /// screen for a choice made in one corner of it.
  popover,
}

/// Sets [AppSheetPresentation] for everything below it. One scope switches
/// every picker a subtree opens, so no picker needs to know where it is.
class AppSheetPresentationScope extends InheritedWidget {
  const AppSheetPresentationScope({
    super.key,
    required this.presentation,
    required super.child,
  });

  final AppSheetPresentation presentation;

  /// [AppSheetPresentation.sheet] when no scope is above [context].
  static AppSheetPresentation of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSheetPresentationScope>()
          ?.presentation ??
      AppSheetPresentation.sheet;

  @override
  bool updateShouldNotify(AppSheetPresentationScope oldWidget) =>
      presentation != oldWidget.presentation;
}
