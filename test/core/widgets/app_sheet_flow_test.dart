import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet.dart';
import 'package:amble/core/widgets/app_sheet_flow.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _theme = AmbleTheme.light;

class _FormPage extends StatefulWidget {
  const _FormPage();

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppSheetFlowHeader(theme: _theme, title: 'Form'),
      Text('Count $_count'),
      TextButton(
        onPressed: () => setState(() => _count++),
        child: const Text('Bump'),
      ),
      TextButton(
        onPressed: () => AppSheetFlow.of(context).push(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetFlowHeader(theme: _theme, title: 'Picker'),
              const SizedBox(height: 200, child: Text('Picker body')),
            ],
          ),
        ),
        child: const Text('Open picker'),
      ),
    ],
  );
}

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [_theme]),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => AppSheet.show<void>(
                context: context,
                builder: (_) =>
                    AppSheetFlow(theme: _theme, root: const _FormPage()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a deeper page slides in over the form in the SAME sheet, with '
      'a back button, and one handle', (tester) async {
    await open(tester);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Picker body'), findsOneWidget);
    expect(find.text('Form').hitTestable(), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byType(AppSheetHandle), findsOneWidget);
  });

  testWidgets('back returns to the form with its state kept', (tester) async {
    await open(tester);
    await tester.tap(find.text('Bump'));
    await tester.pump();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Picker body'), findsNothing);
    expect(find.text('Count 1'), findsOneWidget);
  });

  testWidgets('system back steps back a page first, then closes', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Picker body'), findsNothing);
    expect(find.text('Count 0'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Count 0'), findsNothing);
  });

  testWidgets('dragging down from a deeper page closes the whole sheet', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Picker body'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.text('Picker body'), findsNothing);
    expect(find.text('Count 0'), findsNothing);
  });

  testWidgets('a very tall page stays capped below the status bar: the back '
      'button is reachable and the body scrolls under the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await open(tester);
    AppSheetFlow.of(tester.element(find.text('Open picker'))).push(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetFlowHeader(theme: _theme, title: 'Tall'),
          AppSheetScrollBody(
            child: Column(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 40, child: Text('Item $i')),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final back = tester.getRect(find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(back.top, greaterThan(47));
    expect(
      find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable(),
      findsOneWidget,
    );
    final sheetTop = tester.getTopLeft(find.byType(AppSheetFlow)).dy;
    expect(844 - sheetTop, lessThan(844 * .6 + 120));

    // The body scrolls on to the phone's bottom edge (under the fade),
    // not to a margin above it.
    final viewport = find.ancestor(
      of: find.text('Item 3'),
      matching: find.byType(SingleChildScrollView),
    );
    expect(tester.getBottomLeft(viewport.first).dy, closeTo(844, .5));

    await tester.drag(find.text('Item 3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byIcon(Icons.arrow_back_ios_new_rounded)), back);
  });

  testWidgets('keepHeight: a short page keeps the height of the page it '
      'covers; without it, the sheet fits the short page', (tester) async {
    Widget shortPage() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetFlowHeader(theme: _theme, title: 'Short'),
        const Text('Short body'),
      ],
    );

    await open(tester);
    final formHeight = tester.getSize(find.byType(AppSheetFlow)).height;
    final flow = AppSheetFlow.of(tester.element(find.text('Open picker')));

    flow.push(shortPage(), keepHeight: true);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(AppSheetFlow)).height,
      closeTo(formHeight, .5),
    );

    flow.pop();
    await tester.pumpAndSettle();
    flow.push(shortPage());
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(AppSheetFlow)).height,
      lessThan(formHeight),
    );
  });
}
