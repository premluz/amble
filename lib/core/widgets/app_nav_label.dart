import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_nav_press.dart';

/// A navigation label — the main nav's destinations and the page-level sub
/// nav's tabs (`AppSubNav`) share it, so both read as one navigation
/// language: `textBody`, bold primary when selected, medium tertiary when
/// not. [height] null keeps the label at its text height (the sub nav,
/// which sits in the page-heading slot); the main nav passes its 40px row.
/// Which navigation an [AppNavLabel] belongs to.
enum AppNavLabelVariant {
  /// The main nav: `textBody`, bold when selected.
  main,

  /// A page's sub nav (`AppSubNav`): the page-heading type
  /// ([PageHeadingTokens]) — one step smaller and regular weight, like the
  /// Day date beside it; selection is shown by colour alone.
  sub,
}

class AppNavLabel extends StatelessWidget {
  const AppNavLabel({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height,
    this.variant = AppNavLabelVariant.main,
    this.highlighted = false,
  });

  final AppNavLabelVariant variant;

  /// Shows the active surface behind the label even when not pressed —
  /// e.g. a drag hovering a sub-nav tab.
  final bool highlighted;

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? height;

  /// The label's text style, for anything that must match it exactly.
  static TextStyle styleFor(
    AmbleTheme theme, {
    required bool selected,
    AppNavLabelVariant variant = AppNavLabelVariant.main,
  }) {
    final color = selected ? theme.colorTextPrimary : theme.colorTextTertiary;
    return switch (variant) {
      AppNavLabelVariant.main => theme.textBody.copyWith(
        color: color,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      AppNavLabelVariant.sub => PageHeadingTokens.text(
        theme,
      ).copyWith(color: color),
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: styleFor(theme, selected: selected, variant: variant),
    );
    final rowHeight = height;
    return AppNavPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      builder: (context, pressed) {
        // The active surface hugs the TEXT, not the taller hit box.
        final washed = AppNavWash(visible: pressed || highlighted, child: text);
        // In the main nav: the full row height, not just the text's own
        // intrinsic bounds — see `AppTopNav.build`'s own comment on why
        // this bar's hit area matches `AppTabSwitch`'s 40px track exactly.
        // `Center` keeps the text vertically centered inside that box.
        return rowHeight == null
            ? washed
            : SizedBox(
                height: rowHeight,
                child: Center(child: washed),
              );
      },
    );
  }
}
