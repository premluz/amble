import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_flow.dart';
import 'app_sheet_header.dart';

/// Tells a page of an [AppSheetFlow] whether it is the flow's first page.
class AppSheetFlowPageScope extends InheritedWidget {
  const AppSheetFlowPageScope({
    super.key,
    required this.isRoot,
    required super.child,
  });

  final bool isRoot;

  @override
  bool updateShouldNotify(AppSheetFlowPageScope oldWidget) =>
      isRoot != oldWidget.isRoot;
}

/// A page's header inside an [AppSheetFlow]: × on the first page, ‹ on
/// deeper ones, [title] centred, [trailing] the page's action. Outside a
/// flow it is a plain closing header, so a page also works as its own sheet.
class AppSheetFlowHeader extends StatelessWidget {
  const AppSheetFlowHeader({
    super.key,
    required this.theme,
    this.title,
    this.trailing,
  });

  final AmbleTheme theme;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final flow = AppSheetFlow.maybeOf(context);
    final isRoot =
        context
            .dependOnInheritedWidgetOfExactType<AppSheetFlowPageScope>()
            ?.isRoot ??
        true;
    return AppSheetHeader(
      theme: theme,
      title: title,
      trailing: trailing,
      back: !isRoot,
      showHandle: flow == null,
      onClose: () => flow == null ? Navigator.of(context).pop() : flow.pop(),
    );
  }
}
