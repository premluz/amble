import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_modal_route.dart';
import 'package:amble/core/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _value = Provider<String>((ref) => 'root');

void main() {
  for (final standardSheet in [true, false]) {
    testWidgets('root sheet covers nested chrome and keeps overrides: $standardSheet', (tester) async {
      final root = GlobalKey<NavigatorState>();
      final nested = GlobalKey<NavigatorState>();
      late BuildContext launchContext;
      var headerTaps = 0;
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        navigatorKey: root,
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(resizeToAvoidBottomInset: false, body: Column(children: [
          TextButton(onPressed: () => headerTaps++, child: const Text('Header')),
          Expanded(child: Navigator(key: nested, onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ProviderScope(overrides: [_value.overrideWithValue('edit')],
              child: Builder(builder: (context) {
                launchContext = context;
                return const Text('Day');
              })),
          ))),
          const Text('Toolbar'),
        ])),
      )));
      final toolbar = tester.getRect(find.text('Toolbar'));
      Widget content(BuildContext context) => Align(alignment: Alignment.bottomCenter,
        child: Consumer(builder: (context, ref, _) => TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.watch(_value)),
        )));
      if (standardSheet) {
        AppSheet.show<void>(context: launchContext, builder: content);
      } else {
        pushAppSheetRoute<void>(launchContext, content);
      }
      await tester.pumpAndSettle();
      expect(ModalRoute.of(tester.element(find.text('edit')))!.navigator, same(root.currentState));
      expect(nested.currentState!.canPop(), isFalse);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Toolbar')), toolbar);
      await tester.tap(find.text('Header'), warnIfMissed: false);
      expect(headerTaps, 0);
      await tester.pumpAndSettle();
      if (find.text('edit').evaluate().isNotEmpty) {
        await tester.tap(find.text('edit'));
        await tester.pumpAndSettle();
      }
      expect(find.text('edit'), findsNothing);
      expect(find.text('Day'), findsOneWidget);
    });
  }
}
