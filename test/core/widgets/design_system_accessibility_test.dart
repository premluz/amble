import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_connected_buttons.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_selectable_chip.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  void expectButtonSemantics(
    SemanticsNode node, {
    required String label,
    required bool selected,
  }) {
    final data = node.getSemanticsData();
    expect(data.label, label);
    expect(data.flagsCollection.isButton, isTrue);
    expect(
      data.flagsCollection.isSelected,
      selected ? Tristate.isTrue : Tristate.none,
    );
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  }

  testWidgets(
    'AppButton exposes its real action to keyboard and assistive input',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, AppButton(label: 'Save', onPressed: () {}));

      final button = find.semantics.byPredicate((node) {
        final data = node.getSemanticsData();
        return data.label == 'Save' &&
            data.flagsCollection.isButton &&
            data.hasAction(SemanticsAction.tap);
      });
      expect(button, findsOneWidget);
      expectButtonSemantics(
        button.evaluate().single,
        label: 'Save',
        selected: false,
      );
      semantics.dispose();
    },
  );

  testWidgets('AppButton activates through keyboard focus', (tester) async {
    var calls = 0;
    await pump(tester, AppButton(label: 'Save', onPressed: () => calls++));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(calls, 2);
  });

  testWidgets('selection primitives expose selected state and tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      Column(
        children: [
          AppSelectableChip(label: 'Today', selected: true, onTap: () {}),
          AppTabSwitch<String>(
            options: const [
              AppOptionSwitchOption(value: 'one', label: 'One'),
              AppOptionSwitchOption(value: 'two', label: 'Two'),
            ],
            value: 'one',
            onChanged: (_) {},
          ),
          AppConnectedButtons<String>(
            options: const [
              AppOptionSwitchOption(value: 'one', label: 'One'),
              AppOptionSwitchOption(value: 'two', label: 'Two'),
            ],
            value: 'one',
            onChanged: (_) {},
          ),
        ],
      ),
    );

    expectButtonSemantics(
      tester.getSemantics(find.byType(AppSelectableChip)),
      label: 'Today',
      selected: true,
    );
    expect(
      tester
          .getSemantics(find.byType(AppSelectableChip))
          .getSemanticsData()
          .flagsCollection
          .isInMutuallyExclusiveGroup,
      isFalse,
    );
    final selectedOne = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.label == 'One' &&
          data.flagsCollection.isButton &&
          data.flagsCollection.isSelected == Tristate.isTrue &&
          data.hasAction(SemanticsAction.tap);
    });
    expect(selectedOne, findsNWidgets(2));

    final unselectedTwo = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.label == 'Two' &&
          data.flagsCollection.isButton &&
          data.flagsCollection.isSelected == Tristate.isFalse &&
          data.hasAction(SemanticsAction.tap);
    });
    expect(unselectedTwo, findsNWidgets(2));
    semantics.dispose();
  });
}
