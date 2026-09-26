import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required String viewId,
  required Widget child,
  bool ready = true,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: AppViewTransition(viewId: viewId, ready: ready, child: child),
  ),
);

void main() {
  testWidgets('keeps outgoing content until the ready view crossfades', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(viewId: 'day', child: const Text('Day')));
    await tester.pumpWidget(
      _host(
        viewId: 'inbox',
        ready: false,
        child: TextButton(onPressed: () => taps++, child: const Text('Inbox')),
      ),
    );
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);

    await tester.tap(find.text('Inbox'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpWidget(
      _host(
        viewId: 'inbox',
        ready: true,
        child: TextButton(onPressed: () => taps++, child: const Text('Inbox')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Day'), findsNothing);
    await tester.tap(find.text('Inbox'));
    expect(taps, 1);
  });

  testWidgets('reduced motion completes after layout readiness', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(viewId: 'day', child: const Text('Day'), reducedMotion: true),
    );
    await tester.pumpWidget(
      _host(viewId: 'inbox', child: const Text('Inbox'), reducedMotion: true),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Day'), findsNothing);
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets(
    'ordinary rebuild with the same view ID does not retain old content',
    (tester) async {
      await tester.pumpWidget(_host(viewId: 'day', child: const Text('First')));
      await tester.pumpWidget(
        _host(viewId: 'day', child: const Text('Updated')),
      );
      expect(find.text('First'), findsNothing);
      expect(find.text('Updated'), findsOneWidget);
    },
  );

  testWidgets('rapid changes continue from the current visual state', (
    tester,
  ) async {
    await tester.pumpWidget(_host(viewId: 'a', child: const Text('A')));
    await tester.pumpWidget(_host(viewId: 'b', child: const Text('B')));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_host(viewId: 'c', child: const Text('C')));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
