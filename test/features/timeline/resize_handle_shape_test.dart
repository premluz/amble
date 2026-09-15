import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';

/// Requested directly: "the resize controls should be small blue circles
/// in the center on both ends, at the moment is line, instead in the same
/// position circle/oval centered."
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(WidgetTester tester, {Alignment? barAlignment}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: ResizeHandle(
            theme: theme,
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            barAlignment: barAlignment ?? Alignment.center,
          ),
        ),
      ),
    );
  }

  testWidgets('the visible handle is a circle, not a bar', (tester) async {
    await pump(tester);

    final decoration =
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.shape == BoxShape.circle);

    expect(decoration.shape, BoxShape.circle);
    expect(
      decoration.borderRadius,
      isNull,
      reason: 'a circle uses BoxShape.circle, not a rounded rect — the old '
          'bar used borderRadius instead',
    );
  });

  testWidgets('the handle is accent-colored, not the old grey', (
    tester,
  ) async {
    await pump(tester);

    final decoration =
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.shape == BoxShape.circle);

    expect(
      decoration.color,
      theme.colorAccent,
      reason: 'matches the selection border\'s own accent color, so the '
          'two read as one consistent "editable" visual language',
    );
  });

  // Corrected TWICE against the original placement: first landing the dot
  // centered exactly ON the handle's own edge (half painted inside the
  // pill, half outside — "should be slight outer, not inner like now or
  // middle on the blue line, then part is inner part outer"), then
  // shifted its FULL diameter outward so the whole dot clears the
  // boundary and sits flush against the outside of it.
  testWidgets(
    'topCenter: the dot is pushed its OWN diameter past the handle\'s '
    'edge — fully outside, not straddling it',
    (tester) async {
      await pump(tester, barAlignment: Alignment.topCenter);

      final handleRect = tester.getRect(find.byType(ResizeHandle));
      final circleRect = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );

      expect(
        circleRect.bottom,
        closeTo(handleRect.top, 0.5),
        reason:
            'the dot\'s bottom edge must land exactly at the handle\'s '
            'own top boundary — flush outside it, not centered on it',
      );
      expect(
        circleRect.center.dx,
        closeTo(handleRect.center.dx, 0.5),
        reason: 'horizontally centered regardless of vertical alignment',
      );
    },
  );

  testWidgets(
    'bottomCenter: the dot pushes outward in the OPPOSITE direction',
    (tester) async {
      await pump(tester, barAlignment: Alignment.bottomCenter);

      final handleRect = tester.getRect(find.byType(ResizeHandle));
      final circleRect = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );

      expect(
        circleRect.top,
        closeTo(handleRect.bottom, 0.5),
        reason: 'a bottom handle pushes its dot DOWN, clear of the '
            'handle\'s own bottom boundary',
      );
    },
  );

  testWidgets('the circle is small — a subtle dot, not a large control', (
    tester,
  ) async {
    await pump(tester);

    final circleRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
    );

    expect(circleRect.width, theme.spacingSm);
    expect(circleRect.height, theme.spacingSm);
    expect(circleRect.width, circleRect.height, reason: 'a circle, not an oval, at this size');
  });

  // `outwardShiftFactor: 0.0` keeps the dot centered on the edge — the
  // pre-outward-push behavior, still available for a caller that needs it.
  testWidgets(
    'outwardShiftFactor: 0.0 keeps the dot centered on the edge — no '
    'outward shift at all',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: ResizeHandle(
              theme: theme,
              onDragStart: (_) {},
              onDragUpdate: (_) {},
              onDragEnd: (_) {},
              barAlignment: Alignment.topCenter,
              outwardShiftFactor: 0.0,
            ),
          ),
        ),
      );

      final handleRect = tester.getRect(find.byType(ResizeHandle));
      final circleRect = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );

      expect(
        circleRect.center.dy,
        closeTo(handleRect.top + circleRect.height / 2, 0.5),
        reason: 'centered exactly on the handle\'s own edge — zero shift',
      );
    },
  );

  // `TaskCapsuleBlock` passes `outwardShiftFactor: 0.5` — see that field's
  // own doc comment: its resize handles sit inside a frosted wrapper
  // whose ClipRRect is ALWAYS present, clipping a dot pushed a FULL
  // diameter past the pill's own edge entirely invisible (reported
  // directly: "on task can't see at all now"), while zero shift read as
  // fully inward ("position more outward instead of inward or middle").
  // Half a diameter is the geometry actually shipped for that caller.
  testWidgets(
    'outwardShiftFactor: 0.5 shifts the dot HALFWAY between centered and '
    'fully cleared',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: ResizeHandle(
              theme: theme,
              onDragStart: (_) {},
              onDragUpdate: (_) {},
              onDragEnd: (_) {},
              barAlignment: Alignment.topCenter,
              outwardShiftFactor: 0.5,
            ),
          ),
        ),
      );

      final handleRect = tester.getRect(find.byType(ResizeHandle));
      final circleRect = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );

      // At factor 0.0 the dot's center sits at handleRect.top + height/2
      // (Container(alignment: topCenter) pins the dot's own TOP to the
      // handle's top with no shift). At factor 1.0 it's shifted a full
      // diameter to handleRect.top - height/2 (confirmed by the sibling
      // "fully outside" test above, via circleRect.bottom == handleRect
      // .top). 0.5 lands exactly halfway between those two centers — at
      // handleRect.top itself.
      expect(
        circleRect.center.dy,
        closeTo(handleRect.top, 0.5),
        reason: 'a 0.5 factor moves the dot half its own diameter past '
            'where a 0.0 factor would sit — halfway to the full '
            '(1.0-factor) shift, landing its center exactly on the edge',
      );
    },
  );
}
