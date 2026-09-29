import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_sheet_flow.dart';

/// A label's color: a page of the label's sheet ([AppSheetFlow]), opened
/// from its Color chip.
class CategoryColorPage extends StatefulWidget {
  const CategoryColorPage({
    super.key,
    this.selectedColorToken,
    required this.onSelected,
  });

  final int? selectedColorToken;

  /// The chosen value; the caller updates its form and goes back a page.
  final ValueChanged<int> onSelected;

  @override
  State<CategoryColorPage> createState() => _CategoryColorPageState();
}

class _CategoryColorPageState extends State<CategoryColorPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(theme: theme, title: 'Color'),
        SizedBox(height: theme.spacingMd),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (var index = 0; index < theme.categorySwatches.length; index++)
              _CategoryColorOption(
                color: theme.categorySwatches[index],
                selected: widget.selectedColorToken == index,
                onSelected: () => widget.onSelected(index),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryColorOption extends StatelessWidget {
  const _CategoryColorOption({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final Color color;
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
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
      ),
    );
  }
}
