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
}
