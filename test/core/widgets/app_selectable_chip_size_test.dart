import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart' show AppButtonVariant;
import 'package:amble/core/widgets/app_selectable_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `regular` is the roomier option-picker chip (body text, wider padding)
/// that several screens used to hand-build as private copies; `compact`
/// stays the default and is unchanged.
void main() {
  final theme = AmbleTheme.light;

  Future<Text> pump(WidgetTester tester, AppSelectableChipSize size) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: Center(
            child: AppSelectableChip(
              label: 'Option',
              selected: true,
              onTap: () {},
              variant: AppButtonVariant.primary,
              size: size,
            ),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.text('Option'));
  }

  testWidgets('compact (default) keeps caption text and fixed height', (
    tester,
  ) async {
    final text = await pump(tester, AppSelectableChipSize.compact);
    expect(text.style!.fontSize, theme.textCaption.fontSize);
    expect(
      tester.getSize(find.byType(AppSelectableChip)).height,
      ChipTokens.compactHeight(theme),
    );
  });

  testWidgets('regular uses body text and the primary selected fill', (
    tester,
  ) async {
    final text = await pump(tester, AppSelectableChipSize.regular);
    expect(text.style!.fontSize, theme.textBody.fontSize);
    expect(text.style!.color, theme.colorSurfacePrimary);
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text('Option'), matching: find.byType(Container))
          .first,
    );
    expect((box.decoration! as BoxDecoration).color, theme.colorAccent);
  });
}
