import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/category_chip.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/features/timeline/template_chip_strip.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';

/// Requested directly: preset chips and their badges one scale smaller,
/// "essentially same size as these value data chips" — then "labels still
/// see large." Every compact chip shares a value chip's height.
void main() {
  testWidgets('a preset chip is as tall as a value chip, with a compact '
      'badge', (tester) async {
    final theme = AmbleTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppValueChip(label: 'Duration', hasValue: false, onTap: () {}),
              TemplateChip(
                theme: theme,
                template: TaskTemplate.create(
                  title: 'Gym',
                  categoryId: BuiltInCategoryIds.health,
                ),
                category: null,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final valueChip = tester.getSize(find.byType(AppValueChip));
    final presetChip = tester.getSize(find.byType(AppBadgeChip));
    expect(presetChip.height, valueChip.height);
    expect(
      tester.getSize(find.byType(CategoryBadge)).height,
      ChipTokens.compactBadgeSize(theme),
    );
  });

  testWidgets('a label chip is as tall as a value chip', (tester) async {
    final theme = AmbleTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppValueChip(label: 'Duration', hasValue: false, onTap: () {}),
              CategoryChip(
                category: Category(
                  id: BuiltInCategoryIds.health,
                  name: 'Health',
                  colorToken: 4,
                  emoji: '',
                  isBuiltIn: true,
                ),
                selected: false,
                onSelected: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CategoryChip)).height,
      tester.getSize(find.byType(AppValueChip)).height,
    );
  });
}
