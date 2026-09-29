import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_sheet_flow.dart';
import 'category_visual.dart';

/// A label's icon: a page of the label's sheet ([AppSheetFlow]), opened
/// from its Icon chip.
class CategoryIconPage extends StatefulWidget {
  const CategoryIconPage({
    super.key,
    this.selectedIconCodePoint,
    required this.onSelected,
  });

  final int? selectedIconCodePoint;

  /// The chosen value; the caller updates its form and goes back a page.
  final ValueChanged<int> onSelected;

  @override
  State<CategoryIconPage> createState() => _CategoryIconPageState();
}

class _CategoryIconPageState extends State<CategoryIconPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(theme: theme, title: 'Icon'),
        SizedBox(height: theme.spacingMd),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (final icon in curatedCategoryIcons)
              _CategoryIconOption(
                icon: icon,
                selected: widget.selectedIconCodePoint == icon.codePoint,
                onSelected: () => widget.onSelected(icon.codePoint),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryIconOption extends StatelessWidget {
  const _CategoryIconOption({
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final radius = BorderRadius.circular(theme.radiusSm);

    return AppPressFeedback(
      onTap: onSelected,
      borderRadius: radius,
      rippleColor: theme.colorTextPrimary,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        width: theme.spacingXl,
        height: theme.spacingXl,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SheetTokens.inset(theme),
          borderRadius: radius,
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
        child: Icon(icon, size: theme.spacingLg, color: theme.colorTextPrimary),
      ),
    );
  }
}
