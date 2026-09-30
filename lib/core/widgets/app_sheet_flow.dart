import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_sheet_drag_dismiss.dart';
import 'app_sheet_handle.dart';
import 'app_sheet_flow_header.dart';
import 'app_sheet_page_slot.dart';
import 'app_size_reporter.dart';

export 'app_sheet_flow_header.dart' show AppSheetFlowHeader;
export 'app_sheet_scroll_body.dart' show AppSheetScrollBody;

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
  _Entry(this.page, {required this.animateIn, this.minHeight});
  final Widget page;
  final bool animateIn;

  /// See [AppSheetFlowState.push]'s `keepHeight`.
  final double? minHeight;
  final key = UniqueKey();
  var leaving = false;

  /// The page's laid-out height, for a later page that keeps it.
  double? height;
}

class AppSheetFlowState extends State<AppSheetFlow> {
  late final _entries = [_Entry(widget.root, animateIn: false)];

  List<_Entry> get _live => [
    for (final entry in _entries)
      if (!entry.leaving) entry,
  ];

  /// Slides [page] in over the current page.
  ///
  /// [keepHeight]: the page is at least as tall as the one it covers — a
  /// short picker opened from a form (a label's Color) keeps the form's
  /// size instead of the sheet dropping to fit it.
  void push(Widget page, {bool keepHeight = false}) {
    final under = _live.last.height;
    setState(
      () => _entries.add(
        _Entry(page, animateIn: true, minHeight: keepHeight ? under : null),
      ),
    );
  }

  /// How many pages are showing or kept underneath.
  int get depth => _live.length;

  /// Back to page [depth] (1 = the first) in one step — a choice made
  /// several pages deep returning to the form that asked for it.
  void popTo(int depth) {
    final live = _live;
    if (depth < 1 || depth >= live.length) return;
    setState(() {
      for (final entry in live.skip(depth)) {
        entry.leaving = true;
      }
    });
  }

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

  /// [SheetTokens.flowMaxHeightShare] of the screen, or less when the top
  /// safe area and a raised keyboard leave less.
  double _maxPageHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final room =
        height -
        MediaQuery.paddingOf(context).top -
        MediaQuery.viewInsetsOf(context).bottom -
        widget.theme.spacingXl;
    return math.max(0, math.min(height * SheetTokens.flowMaxHeightShare, room));
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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _maxPageHeight(context)),
              // A page's scroll body runs on below the page into the
              // sheet's bottom space (`AppSheetScrollBody`): no clip.
              child: Stack(
                clipBehavior: Clip.none,
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
                      child: AppSheetFlowPageScope(
                        isRoot: identical(entry, _entries.first),
                        child: AppSizeReporter(
                          onSize: (size) => entry.height = size.height,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: entry.minHeight ?? 0,
                            ),
                            child: entry.page,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
