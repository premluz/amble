import 'package:amble/core/tokens/follow_through_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_page_toolbar.dart';
import 'package:amble/core/widgets/app_spring_presence.dart';
import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _page(String id) => Stack(
  key: ValueKey('page-$id'),
  children: [
    Positioned(
      right: 16,
      bottom: 16,
      child: AppPageToolbarItem(
        child: SizedBox(key: ValueKey('tool-$id'), width: 48, height: 48),
      ),
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

bool _showing(WidgetTester tester, String id) => tester
    .widget<AppSpringPresence>(
      find.ancestor(
        of: find.byKey(ValueKey('tool-$id')),
        matching: find.byType(AppSpringPresence),
      ),
    )
    .visible;

void main() {
  testWidgets('at app start the page toolbar is simply there', (tester) async {
    await tester.pumpWidget(_host('a', forward: true));
    expect(_showing(tester, 'a'), isTrue);
  });

  testWidgets('leaving: it submerges at once and stays in place while its '
      'page slides away; arriving: the new one emerges once the old has '
      'gone', (tester) async {
    await tester.pumpWidget(_host('a', forward: true));
    final restingRect = tester.getRect(find.byKey(const ValueKey('tool-a')));
    await tester.pumpWidget(_host('b', forward: true));
    await tester.pump();
    await tester.pump(FollowThroughSpec.pages.duration * .3);
    expect(_showing(tester, 'a'), isFalse, reason: 'submerging');
    expect(
      tester.getRect(find.byKey(const ValueKey('tool-a'))).center,
      restingRect.center,
      reason: 'held in place, not sliding with its page',
    );
    expect(_showing(tester, 'b'), isFalse, reason: 'waits for the old one');
    await tester.pump(AppPageToolbarGate.revealDelay);
    expect(_showing(tester, 'b'), isTrue, reason: 'then emerges');
    await tester.pumpAndSettle();
  });

  testWidgets('coming back to a page, its toolbar emerges again', (
    tester,
  ) async {
    await tester.pumpWidget(_host('a', forward: true));
    await tester.pumpWidget(_host('b', forward: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host('a', forward: false));
    await tester.pump();
    expect(_showing(tester, 'a'), isFalse);
    await tester.pump(AppPageToolbarGate.revealDelay);
    expect(_showing(tester, 'a'), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('outside a sliding page it is always showing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppPageToolbarItem(child: SizedBox(key: ValueKey('tool-x'))),
      ),
    );
    expect(_showing(tester, 'x'), isTrue);
  });

  testWidgets('several buttons on a page stagger, left to right, going out '
      'and coming in', (tester) async {
    Widget page(String id) => Row(
      key: ValueKey('page-$id'),
      children: [
        for (var i = 0; i < 2; i++)
          AppPageToolbarItem(
            order: i,
            child: SizedBox(key: ValueKey('tool-$id$i'), width: 48, height: 48),
          ),
      ],
    );
    Widget host(String id, bool forward) => MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.light]),
      home: AppViewTransition(
        viewId: id,
        slide: true,
        forward: forward,
        child: page(id),
      ),
    );
    const step = AppPageToolbarGate.stagger;
    await tester.pumpWidget(host('a', true));
    await tester.pumpWidget(host('b', true));
    await tester.pump();
    expect(_showing(tester, 'a0'), isFalse, reason: 'first goes at once');
    expect(_showing(tester, 'a1'), isTrue, reason: 'second a step later');
    await tester.pump(step);
    expect(_showing(tester, 'a1'), isFalse);

    await tester.pump(AppPageToolbarGate.revealDelay - step);
    expect(_showing(tester, 'b0'), isTrue, reason: 'first comes in');
    expect(_showing(tester, 'b1'), isFalse, reason: 'second a step later');
    await tester.pump(step);
    expect(_showing(tester, 'b1'), isTrue);
    await tester.pumpAndSettle();
  });
}
