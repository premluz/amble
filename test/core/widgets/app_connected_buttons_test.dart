import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_connected_buttons.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';

/// New geometry — no prior component in this design system rendered a
/// fused capsule with mutually-exclusive segments before this. See
/// app_connected_buttons.dart's own doc comment for how it differs from
/// AppTabSwitch and from AppSelectableChip.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: child),
    ),
  );

  const options = [
    AppOptionSwitchOption(value: 'money', label: 'Money'),
    AppOptionSwitchOption(value: 'investments', label: 'Investments'),
  ];

  testWidgets('renders every option label', (tester) async {
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: options,
        value: 'money',
        onChanged: (_) {},
      ),
    );

    expect(find.text('Money'), findsOneWidget);
    expect(find.text('Investments'), findsOneWidget);
  });

  testWidgets('tapping an unselected option calls onChanged with its value', (
    tester,
  ) async {
    String? changedTo;
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: options,
        value: 'money',
        onChanged: (value) => changedTo = value,
      ),
    );

    await tester.tap(find.text('Investments'));
    expect(changedTo, 'investments');
  });

  testWidgets('the selected segment has a contrasting fill/color but is '
      'not bold — neither state is (2026-09-19 refinement)', (tester) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: options,
        value: 'money',
        onChanged: (_) {},
      ),
    );

    final selectedText = tester.widget<Text>(find.text('Money'));
    final unselectedText = tester.widget<Text>(find.text('Investments'));

    expect(selectedText.style!.fontWeight, FontWeight.w500);
    expect(selectedText.style!.color, theme.colorSurfacePrimary);
    expect(unselectedText.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('the whole group renders as one outer capsule shape', (
    tester,
  ) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: options,
        value: 'money',
        onChanged: (_) {},
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(theme.radiusPill));
  });

  testWidgets('ghost variant shows a hairline outline instead of a filled '
      'track', (tester) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: options,
        value: 'money',
        variant: AppButtonVariant.ghost,
        onChanged: (_) {},
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.border!.top.color, theme.colorBorder);
  });

  testWidgets('supports more than two options', (tester) async {
    const threeOptions = [
      AppOptionSwitchOption(value: 'a', label: 'A'),
      AppOptionSwitchOption(value: 'b', label: 'B'),
      AppOptionSwitchOption(value: 'c', label: 'C'),
    ];
    await pump(
      tester,
      AppConnectedButtons<String>(
        options: threeOptions,
        value: 'b',
        onChanged: (_) {},
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });
}
