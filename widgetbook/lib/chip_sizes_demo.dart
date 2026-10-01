import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/category_chip.dart';
import 'package:amble/features/timeline/template_chip_strip.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:flutter/material.dart';

/// Every compact chip side by side, so a size drift shows at a glance —
/// requested directly: "labels still see large, maybe they need comp in
/// widget book?" All of them should share one height (a value chip's).
Widget chipSizesDemo(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  final health = Category(
    id: BuiltInCategoryIds.health,
    name: 'Health',
    colorToken: 4,
    emoji: '',
    isBuiltIn: true,
  );
  final gym = TaskTemplate.create(title: 'Gym', categoryId: health.id);
  final chips = <(String, Widget)>[
    (
      'Value chip',
      AppValueChip(label: 'Duration', hasValue: false, onTap: () {}),
    ),
    (
      'Value chip, set',
      AppValueChip(label: '45m', hasValue: true, onTap: () {}),
    ),
    (
      'Preset chip',
      TemplateChip(theme: theme, template: gym, category: health, onTap: () {}),
    ),
    (
      'Label chip',
      CategoryChip(category: health, selected: false, onSelected: () {}),
    ),
    (
      'Label chip, selected',
      CategoryChip(category: health, selected: true, onSelected: () {}),
    ),
  ];
  return ColoredBox(
    color: theme.colorSurfacePrimary,
    child: ListView(
      padding: EdgeInsets.all(theme.spacingLg),
      children: [
        Text('Together', style: theme.textCaption),
        SizedBox(height: theme.spacingSm),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [for (final (_, chip) in chips) chip],
        ),
        for (final (name, chip) in chips) ...[
          SizedBox(height: theme.spacingLg),
          Text(name, style: theme.textCaption),
          SizedBox(height: theme.spacingSm),
          Align(alignment: Alignment.centerLeft, child: chip),
        ],
      ],
    ),
  );
}
