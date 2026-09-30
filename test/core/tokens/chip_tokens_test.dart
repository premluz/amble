import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_selectable_chip.dart';
import 'package:amble/core/widgets/app_step_scaffold.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [theme]),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Color? fillOf(WidgetTester tester, Finder of) {
    for (final box in tester.widgetList<Container>(
      find.descendant(of: of, matching: find.byType(Container)),
    )) {
      if (box.decoration case BoxDecoration(:final color?)) return color;
    }
    return null;
  }

  testWidgets('compact chips share one height and rest fill', (tester) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppValueChip(label: 'Preset', hasValue: false, onTap: () {}),
          AppSelectableChip(label: 'Mon', selected: false, onTap: () {}),
        ],
      ),
    );
    for (final chip in [
      find.byType(AppValueChip),
      find.byType(AppSelectableChip),
    ]) {
      expect(tester.getSize(chip).height, ChipTokens.compactHeight(theme));
      expect(fillOf(tester, chip), ChipTokens.restFill(theme));
    }
    final rest = tester.widget<Text>(find.text('Mon')).style!;
    expect(rest.color, ChipTokens.restText(theme));
    expect(rest.fontWeight, ChipTokens.restWeight);
  });

  testWidgets('a regular picker option is the regular height; selected is '
      'primary text at the selected weight', (tester) async {
    await pump(
      tester,
      AppSelectableChip(
        label: 'Butter',
        selected: true,
        size: AppSelectableChipSize.regular,
        onTap: () {},
      ),
    );
    expect(
      tester.getSize(find.byType(AppSelectableChip)).height,
      ChipTokens.regularHeight(theme),
    );
    final style = tester.widget<Text>(find.text('Butter')).style!;
    expect(style.color, ChipTokens.selectedText(theme));
    expect(style.fontWeight, ChipTokens.selectedWeight);
  });

  testWidgets('the sheet header × is as quiet as a chip at rest', (
    tester,
  ) async {
    await pump(
      tester,
      HeaderCircleButton(theme: theme, icon: Icons.close_rounded, onTap: () {}),
    );
    expect(
      fillOf(tester, find.byType(HeaderCircleButton)),
      ChipTokens.restFill(theme),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.close_rounded)).color,
      ChipTokens.restText(theme),
    );
  });

  testWidgets('a preset badge rests on the chip rest fill, not the stronger '
      'selected glass', (tester) async {
    await pump(tester, AppBadgeChip(theme: theme, label: 'Running'));
    final fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AppBadgeChip),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>();
    expect(fills, contains(ChipTokens.restFill(theme)));
    expect(fills, isNot(contains(AppButton.subtleTint(theme))));
  });
}
