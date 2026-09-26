import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_chip_strip.dart';

/// Covers the shared horizontal-scroll-strip mechanics extracted from
/// `template_chip_strip.dart`'s own `TemplateChipStrip` — requested
/// directly ("we should make that scrolling same across usages, document
/// in design system so we reuse that class"). A second real caller (the
/// New Zone sheet's own tag-picker row) now builds on this instead of
/// hand-rolling a second `ListView.separated`.
void main() {
  final theme = AmbleTheme.light;

  Widget chip(String label) =>
      Container(width: 60, alignment: Alignment.center, child: Text(label));

  Future<void> pump(
    WidgetTester tester, {
    required List<String> items,
    double height = 40,
    double? itemSpacing,
    double? edgeInset,
    bool withKeys = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: AppChipStrip<String>(
            items: items,
            height: height,
            itemSpacing: itemSpacing,
            edgeInset: edgeInset,
            keyOf: withKeys ? (item) => ValueKey(item) : null,
            itemBuilder: (context, item) => chip(item),
          ),
        ),
      ),
    );
  }

  testWidgets('renders every item, in order', (tester) async {
    await pump(tester, items: ['A', 'B', 'C']);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('an empty item list renders nothing, not an empty scroll '
      'view', (tester) async {
    await pump(tester, items: const []);

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('renders at exactly the given height', (tester) async {
    await pump(tester, items: ['A'], height: 52);

    expect(tester.getSize(find.byType(AppChipStrip<String>)).height, 52);
  });

  testWidgets('scrolls horizontally — a ListView with Axis.horizontal', (
    tester,
  ) async {
    await pump(tester, items: ['A', 'B', 'C']);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.scrollDirection, Axis.horizontal);
  });

  testWidgets(
    'defaults item spacing to theme.spacingSm when none is given',
    (tester) async {
      await pump(tester, items: ['A', 'B']);

      final gap = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere((box) => box.width != null && box.height == null);
      expect(gap.width, theme.spacingSm);
    },
  );

  testWidgets('uses a custom itemSpacing when given', (tester) async {
    await pump(tester, items: ['A', 'B'], itemSpacing: 24);

    final gap = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .firstWhere((box) => box.width != null && box.height == null);
    expect(gap.width, 24);
  });

  testWidgets('defaults edgeInset to 0 when none is given', (tester) async {
    await pump(tester, items: ['A']);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding, EdgeInsets.zero);
  });

  testWidgets('applies a custom edgeInset symmetrically', (tester) async {
    await pump(tester, items: ['A'], edgeInset: 16);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding, const EdgeInsets.symmetric(horizontal: 16));
  });

  testWidgets('keyOf gives each item a stable key for state preservation', (
    tester,
  ) async {
    await pump(tester, items: ['A', 'B'], withKeys: true);

    expect(find.byKey(const ValueKey('A')), findsOneWidget);
    expect(find.byKey(const ValueKey('B')), findsOneWidget);
  });

  testWidgets('omitting keyOf still renders correctly, with no crash', (
    tester,
  ) async {
    await pump(tester, items: ['A', 'B']);

    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
