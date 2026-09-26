import 'package:amble/core/tokens/what_matters_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/what_matters_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _leaving = ValueKey('leaving');
const _anchor = ValueKey('anchor');

Future<void> _mount(
  WidgetTester tester,
  ValueNotifier<bool> enabled,
  AmbleTheme theme, {
  bool reduced = false,
  bool lazy = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(
      brightness: theme == AmbleTheme.dark ? Brightness.dark : Brightness.light,
      extensions: [theme],
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (context, value, _) => WhatMattersScene(
          enabled: value,
          child: Align(
            alignment: Alignment.topCenter,
            child: _rows(value, lazy),
          ),
        ),
      ),
    ),
  ),
);

Widget _rows(bool value, bool lazy) {
  final children = [
    WhatMattersMotion(
      key: _leaving,
      hidden: value,
      collapse: true,
      child: const SizedBox(height: 100, width: 100, child: Text('Ordinary')),
    ),
    const SizedBox(
      key: _anchor,
      height: 100,
      width: 100,
      child: Text('Important'),
    ),
  ];
  return lazy ? ListView(children: children) : Column(children: children);
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: find.byKey(_leaving), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    testWidgets(
      '${theme == AmbleTheme.light ? 'light' : 'dark'}: holds anchors, releases, then closes gaps',
      (tester) async {
        final enabled = ValueNotifier(false);
        addTearDown(enabled.dispose);
        await _mount(tester, enabled, theme);
        final origin = tester.getTopLeft(find.byKey(_anchor));
        enabled.value = true;
        await tester.pump();
        await tester.pump(
          WhatMattersTokens.enter * WhatMattersTokens.releaseStart,
        );
        expect(tester.getTopLeft(find.byKey(_anchor)), origin);
        expect(_opacity(tester), 1);
        await tester.pump(
          WhatMattersTokens.enter *
              (WhatMattersTokens.collapseStart -
                  WhatMattersTokens.releaseStart),
        );
        expect(tester.getTopLeft(find.byKey(_anchor)), origin);
        expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
        await tester.pump(
          WhatMattersTokens.enter *
              (WhatMattersTokens.releaseEnd - WhatMattersTokens.collapseStart),
        );
        expect(_opacity(tester), closeTo(0, .001));
        expect(tester.getTopLeft(find.byKey(_anchor)).dy, lessThan(origin.dy));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(_leaving)).height, closeTo(0, .01));
        expect(find.text('Ordinary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'return holds briefly, then expands and restores content within the return duration',
    (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await _mount(tester, enabled, AmbleTheme.light);
      enabled.value = false;
      await tester.pump();
      await tester.pump(
        WhatMattersTokens.leave * WhatMattersTokens.returnStart,
      );
      expect(tester.getSize(find.byKey(_leaving)).height, closeTo(0, .01));
      await tester.pump(
        WhatMattersTokens.leave * ((1 - WhatMattersTokens.returnStart) / 2),
      );
      expect(
        tester.getSize(find.byKey(_leaving)).height,
        inExclusiveRange(0, 100),
      );
      expect(_opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(
        WhatMattersTokens.leave * ((1 - WhatMattersTokens.returnStart) / 2),
      );
      expect(tester.getSize(find.byKey(_leaving)).height, 100);
      expect(_opacity(tester), 1);
    },
  );

  testWidgets('rapid reversal preserves the current pose and restores space', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await _mount(tester, enabled, AmbleTheme.light);
    enabled.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final before = _opacity(tester);
    final height = tester.getSize(find.byKey(_leaving)).height;
    enabled.value = false;
    await tester.pump();
    expect(_opacity(tester), before);
    expect(tester.getSize(find.byKey(_leaving)).height, height);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(tester.getSize(find.byKey(_leaving)).height, 100);
  });

  testWidgets('reduced motion applies the final layout immediately', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await _mount(tester, enabled, AmbleTheme.dark, reduced: true);
    enabled.value = true;
    await tester.pump();
    expect(_opacity(tester), 0);
    expect(tester.getSize(find.byKey(_leaving)).height, closeTo(0, .01));
    await tester.pumpAndSettle();
  });
  testWidgets('collapsed lazy-list rows hold their pose when restored', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await _mount(tester, enabled, AmbleTheme.light, lazy: true);
    enabled.value = true;
    await tester.pumpAndSettle();
    final hiddenPosition = tester.getTopLeft(find.byKey(_anchor));
    enabled.value = false;
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_anchor)), hiddenPosition);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_leaving)).height, 100);
  });
}
