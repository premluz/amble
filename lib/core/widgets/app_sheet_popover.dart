import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_modal_scope.dart';
import 'app_popover_route.dart';
import 'app_sheet_presentation.dart';
import 'app_sheet_scroll_body.dart';

/// [AppSheet.show]'s popover presentation: the same content a sheet would
/// hold, with the same side inset, in an [AppPopoverRoute] beside the
/// control whose [context] asked for it.
///
/// The content is scoped as a popover too, so a sheet header inside it
/// drops the drag bar (there is nothing to drag) and anything it opens in
/// turn also stays a popover.
Future<T?> showSheetAsPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool padded,
}) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    throw StateError(
      'AppSheet.show in a popover scope needs the context of the control '
      'that opened it, laid out on screen, to anchor the popover to. Got '
      '${box.runtimeType}.',
    );
  }
  final control = box.localToGlobal(Offset.zero) & box.size;
  // Level with the control, but beside the whole scoped area (the panel),
  // so the popover sits next to the panel instead of over it.
  final scope = context
      .getElementForInheritedWidgetOfExactType<AppSheetPresentationScope>()
      ?.findRenderObject();
  final area = scope is RenderBox && scope.hasSize
      ? scope.localToGlobal(Offset.zero) & scope.size
      : control;
  final anchor = Rect.fromLTRB(
    area.left,
    control.top,
    area.right,
    control.bottom,
  );
  final bottom = padded ? SheetTokens.contentBottomInset(theme) : 0.0;
  final side = padded ? theme.spacingLg : 0.0;

  Widget content(BuildContext popoverContext) => AppSheetPresentationScope(
    presentation: AppSheetPresentation.popover,
    child: Material(
      type: MaterialType.transparency,
      child: AppSheetBottomInset(
        value: bottom,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, bottom),
            child: builder(popoverContext),
          ),
        ),
      ),
    ),
  );

  return Navigator.of(context, rootNavigator: true).push<T>(
    AppPopoverRoute<T>(
      anchor: anchor,
      theme: theme,
      builder: rootModalBuilder(context, content),
    ),
  );
}
