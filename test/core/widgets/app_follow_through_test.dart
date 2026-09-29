import 'package:amble/core/tokens/follow_through_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_follow_through.dart';
import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page of three key items stacked top to bottom; the middle one holds
/// two nested dots, left and right.
Widget _page(String id) => Column(
  key: ValueKey('page-$id'),
  children: [
    AppFollowThrough(
      key: ValueKey('$id-top'),
      child: const SizedBox(height: 60),
    ),
    AppFollowThrough(
      key: ValueKey('$id-card'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppFollowThrough(
            key: ValueKey('$id-dot-left'),
            child: const SizedBox(width: 20, height: 20),
          ),
          AppFollowThrough(
            key: ValueKey('$id-dot-right'),
            child: const SizedBox(width: 20, height: 20),
          ),
        ],
      ),
    ),
    const Spacer(),
    AppFollowThrough(
      key: ValueKey('$id-bottom'),
      child: const SizedBox(height: 60),
    ),
  ],
);

Widget _host(String id, {required bool forward}) => MaterialApp(
  theme: ThemeData(extensions: [AmbleTheme.light]),
  home: AppViewTransition(
    viewId: id,
    slide: true,
    forward: forward,
    child: _page(id),
  ),
);

double _lag(WidgetTester tester, String key) => tester
    .renderObject<RenderFollowThrough>(find.byKey(ValueKey(key)))
    .debugLag;

/// Switches to page [to] and pumps to [share] of the follow-through timeline.
Future<void> _switchTo(
  WidgetTester tester,
  String to, {
  required bool forward,
  double share = .4,
}) async {
  await tester.pumpWidget(_host(to, forward: forward));
  await tester.pump(); // readiness: the transition starts next frame
  await tester.pump(FollowThroughSpec.pages.duration * share);
}

void main() {
  testWidgets('at rest, items sit exactly on their page', (tester) async {
    await tester.pumpWidget(_host('a', forward: true));
    await tester.pump();
    expect(_lag(tester, 'a-top'), 0);
    expect(_lag(tester, 'a-bottom'), 0);
  });

  testWidgets('going forward (page moves left): the incoming items trail '
      'to the right, the lower ones more, and all land by the end', (
    tester,
  ) async {
    await tester.pumpWidget(_host('a', forward: true));
    await _switchTo(tester, 'b', forward: true);
    final top = _lag(tester, 'b-top');
    final bottom = _lag(tester, 'b-bottom');
    expect(top, greaterThan(0), reason: 'trailing the leftward travel');
    expect(bottom, greaterThan(top), reason: 'rows lower down follow later');
    await tester.pumpAndSettle();
    expect(_lag(tester, 'b-top'), 0);
    expect(_lag(tester, 'b-bottom'), 0);
  });

  testWidgets('the outgoing page\'s items follow through too, the same way', (
    tester,
  ) async {
    await tester.pumpWidget(_host('a', forward: true));
    await _switchTo(tester, 'b', forward: true);
    expect(_lag(tester, 'a-bottom'), greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('going back (page moves right): items trail to the left', (
    tester,
  ) async {
    await tester.pumpWidget(_host('b', forward: false));
    await _switchTo(tester, 'a', forward: false);
    expect(_lag(tester, 'a-top'), lessThan(0));
    expect(_lag(tester, 'a-bottom'), lessThan(_lag(tester, 'a-top')));
    await tester.pumpAndSettle();
  });

  testWidgets('nested dots trail their own card, and the dot on the '
      'trailing side follows last', (tester) async {
    await tester.pumpWidget(_host('a', forward: true));
    await _switchTo(tester, 'b', forward: true, share: .5);
    final left = _lag(tester, 'b-dot-left');
    final right = _lag(tester, 'b-dot-right');
    // Moving left: the left dot leads, the right one trails its card.
    expect(right, greaterThan(0));
    expect(right, greaterThan(left));
    await tester.pumpAndSettle();
    expect(_lag(tester, 'b-dot-right'), 0);
  });

  testWidgets('outside a sliding page, a follower is inert', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppFollowThrough(key: ValueKey('lone'), child: SizedBox()),
      ),
    );
    expect(_lag(tester, 'lone'), 0);
  });

  for (final forward in [true, false]) {
    testWidgets('the page being left paints above the arriving one '
        '(forward: $forward), so its trailing items are never covered', (
      tester,
    ) async {
      await tester.pumpWidget(_host('a', forward: forward));
      await _switchTo(tester, 'b', forward: forward);
      final stack = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('view-slot-a')),
              matching: find.byType(Stack),
            )
            .first,
      );
      final order = [for (final c in stack.children) c.key];
      expect(
        order.indexOf(const ValueKey('view-slot-a')),
        greaterThan(order.indexOf(const ValueKey('view-slot-b'))),
        reason: 'later children paint on top',
      );
      await tester.pumpAndSettle();

      // And back again: now "b" is the one being left.
      await _switchTo(tester, 'a', forward: !forward);
      final back = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('view-slot-a')),
              matching: find.byType(Stack),
            )
            .first,
      );
      final backOrder = [for (final c in back.children) c.key];
      expect(
        backOrder.indexOf(const ValueKey('view-slot-b')),
        greaterThan(backOrder.indexOf(const ValueKey('view-slot-a'))),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('each item works out where it sits once per slide, not once '
      'per frame — the costly part, with grids of dots', (tester) async {
    await tester.pumpWidget(_host('a', forward: true));
    RenderFollowThrough.debugPlacements = 0;
    await tester.pumpWidget(_host('b', forward: true));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Five followers on each of the two moving pages.
    expect(RenderFollowThrough.debugPlacements, 10);

    // A second slide places them afresh (they may sit elsewhere now).
    RenderFollowThrough.debugPlacements = 0;
    await tester.pumpWidget(_host('a', forward: false));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(RenderFollowThrough.debugPlacements, 10);
  });
}
