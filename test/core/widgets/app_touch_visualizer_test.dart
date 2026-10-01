import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_touch_visualizer.dart';

final _theme = AmbleTheme.light;

Finder _dots() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).color ==
          TouchVisualizerTokens.fill(_theme),
);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('taps $taps'),
    ),
  );
}

Widget _app({required bool enabled}) => MaterialApp(
  theme: ThemeData(extensions: [_theme]),
  builder: (context, child) =>
      AppTouchVisualizer(enabled: enabled, child: child!),
  home: const Scaffold(body: _Counter()),
);

void main() {
  testWidgets('off: no dots, and taps work', (tester) async {
    await tester.pumpWidget(_app(enabled: false));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TextButton)),
    );
    await tester.pump();
    expect(_dots(), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('on: a dot sits under the finger, the tap still lands, and '
      'the dot fades after release', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    final point = tester.getCenter(find.byType(TextButton));
    final gesture = await tester.startGesture(point);
    await tester.pump(TouchVisualizerTokens.appear(_theme));
    expect(_dots(), findsOneWidget);
    expect(tester.getCenter(_dots()), point);

    await gesture.up();
    await tester.pump();
    expect(find.text('taps 1'), findsOneWidget, reason: 'never swallowed');
    expect(_dots(), findsOneWidget, reason: 'fading, not cut');
    // Two fade lengths: its clock starts a frame after the release.
    await tester.pump(TouchVisualizerTokens.release(_theme));
    await tester.pump(TouchVisualizerTokens.release(_theme));
    expect(_dots(), findsNothing);
  });

  testWidgets('one dot per finger', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 300), pointer: 2);
    await tester.pump();
    expect(_dots(), findsNWidgets(2));
    await a.up();
    await b.up();
    await tester.pump(TouchVisualizerTokens.release(_theme));
    await tester.pump();
  });

  testWidgets('switching it on keeps the app underneath as it was', (
    tester,
  ) async {
    await tester.pumpWidget(_app(enabled: false));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pumpWidget(_app(enabled: true));
    expect(find.text('taps 1'), findsOneWidget);
  });
}
