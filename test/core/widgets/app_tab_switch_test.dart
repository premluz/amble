import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';

/// Generalizes the previously-private, 2-option-only `_TabSwitcher`/
/// `_Segment` (zone_grid_screen.dart) into a reusable, arbitrary-length
/// primitive — see app_tab_switch.dart's own doc comment.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: child),
    ),
  );

  const options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
  ];

  testWidgets('renders every option label', (tester) async {
    await pump(
      tester,
      AppTabSwitch<String>(options: options, value: 'all', onChanged: (_) {}),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Crypto'), findsOneWidget);
    expect(find.text('Stocks'), findsOneWidget);
  });

  testWidgets('tapping an unselected option calls onChanged with its value', (
    tester,
  ) async {
    String? changedTo;
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        onChanged: (value) => changedTo = value,
      ),
    );

    await tester.tap(find.text('Crypto'));
    expect(changedTo, 'crypto');
  });

  testWidgets('neither the selected nor unselected segment is bold — '
      'distinguished by fill/color, not weight (2026-09-19 refinement)', (
    tester,
  ) async {
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'crypto',
        onChanged: (_) {},
      ),
    );

    final selectedText = tester.widget<Text>(find.text('Crypto'));
    final unselectedText = tester.widget<Text>(find.text('All'));

    expect(selectedText.style!.fontWeight, FontWeight.w500);
    expect(unselectedText.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('primary variant highlights the selected segment with the '
      'accent fill', (tester) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        onChanged: (_) {},
      ),
    );

    final selectedText = tester.widget<Text>(find.text('All'));
    expect(selectedText.style!.color, theme.colorSurfacePrimary);
  });

  testWidgets('ghost variant has no track fill', (tester) async {
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        variant: AppButtonVariant.ghost,
        onChanged: (_) {},
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, isNull);
  });
}
