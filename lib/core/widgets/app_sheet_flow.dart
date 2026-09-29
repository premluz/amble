import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_drag_dismiss.dart';
import 'app_sheet_handle.dart';
import 'app_sheet_header.dart';
import 'app_sheet_page_slot.dart';

/// One sheet holding a stack of pages — the iOS way to go deeper from a
/// sheet (Label → New label → Color) instead of stacking sheet on sheet,
/// which Material also advises against. [push] slides a page in over the
/// current one; back (‹, Android back, [pop]) slides it away. Pages below
/// stay alive, so a half-filled form keeps its state while a picker is
/// open. The height follows the page on top; the handle bar is drawn once
/// and never moves. Dragging the sheet down closes it whole.
class AppSheetFlow extends StatefulWidget {
  const AppSheetFlow({super.key, required this.theme, required this.root});

  final AmbleTheme theme;
  final Widget root;

  static AppSheetFlowState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppSheetFlowState>();

  static AppSheetFlowState of(BuildContext context) {
    final flow = maybeOf(context);
    if (flow == null) {
      throw FlutterError('AppSheetFlow.of() called outside an AppSheetFlow.');
    }
    return flow;
  }

  @override
  State<AppSheetFlow> createState() => AppSheetFlowState();
}

class _Entry {
  _Entry(this.page, {required this.animateIn});
  final Widget page;
  final bool animateIn;
  final key = UniqueKey();
  var leaving = false;
}

class AppSheetFlowState extends State<AppSheetFlow> {
  late final _entries = [_Entry(widget.root, animateIn: false)];

  List<_Entry> get _live => [
    for (final entry in _entries)
      if (!entry.leaving) entry,
  ];

  /// Slides [page] in over the current page.
  void push(Widget page) =>
      setState(() => _entries.add(_Entry(page, animateIn: true)));

  /// Back one page; on the first page, closes the sheet.
  void pop() {
    final live = _live;
    if (live.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => live.last.leaving = true);
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) return;
    if (AppSheetDragDismiss.isDismissing(context)) {
      Navigator.of(context).pop();
      return;
    }
    pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final live = _live;
    return PopScope(
      canPop: live.length == 1,
      onPopInvokedWithResult: _onPopInvoked,
      child: Stack(
        children: [
          AnimatedSize(
            duration: theme.motionNormal,
            curve: theme.curveStandard,
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                for (final entry in _entries)
                  AppSheetPageSlot(
                    key: entry.key,
                    theme: theme,
                    role: entry.leaving
                        ? AppSheetPageRole.leaving
                        : identical(entry, live.last)
                        ? AppSheetPageRole.top
                        : AppSheetPageRole.below,
                    animateIn: entry.animateIn,
                    onGone: () => setState(() => _entries.remove(entry)),
                    child: _PageScope(
                      isRoot: identical(entry, _entries.first),
                      child: entry.page,
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: AppSheetTopHandle(theme: theme)),
          ),
        ],
      ),
    );
  }
}

class _PageScope extends InheritedWidget {
  const _PageScope({required this.isRoot, required super.child});

  final bool isRoot;

  @override
  bool updateShouldNotify(_PageScope oldWidget) => isRoot != oldWidget.isRoot;
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
        context.dependOnInheritedWidgetOfExactType<_PageScope>()?.isRoot ??
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
