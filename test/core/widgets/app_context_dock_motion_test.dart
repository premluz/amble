import 'package:amble/core/widgets/app_context_dock.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_context_dock_test.dart' show dockHost, dockConfiguration;

void main() {
  testWidgets('selection exits stagger while retained control stays opaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      dockHost(
        dockConfiguration(onSave: () {}, onRemove: () {}, onArchive: () {}),
      ),
    );
    await tester.pumpWidget(dockHost(dockConfiguration(onSave: () {})));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    double opacity(String id) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byKey(ValueKey('dock-action-$id')),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(opacity('remove'), lessThan(1));
    expect(opacity('archive'), 1);
    expect(opacity('save'), 1);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove'), findsNothing);
    expect(find.byTooltip('Archive'), findsNothing);
  });

  testWidgets(
    'new selection actions enter in order while retained action stays visible',
    (tester) async {
      await tester.pumpWidget(dockHost(dockConfiguration(onSave: () {})));
      await tester.pumpWidget(
        dockHost(
          dockConfiguration(onSave: () {}, onRemove: () {}, onArchive: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      double opacity(String id) => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.byKey(ValueKey('dock-action-$id')),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacity('save'), 1);
      expect(opacity('remove'), greaterThan(0));
      expect(opacity('archive'), 0);
      await tester.pumpAndSettle();
      expect(opacity('archive'), 1);
    },
  );

  testWidgets('same Back action stays opaque and stationary across edit tabs', (
    tester,
  ) async {
    AppContextDockConfiguration edit(String state) =>
        AppContextDockConfiguration(
          stateId: state,
          groups: [
            AppContextGroup(
              id: 'context-navigation',
              actions: [
                AppContextAction(
                  id: 'edit-back',
                  icon: Icons.arrow_back_rounded,
                  tooltip: state,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        );
    await tester.pumpWidget(dockHost(edit('tasks')));
    final back = find.byKey(const ValueKey('dock-action-edit-back'));
    final element = tester.element(back);
    final rect = tester.getRect(back);
    await tester.pumpWidget(dockHost(edit('zones')));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.element(back), same(element));
      expect(tester.getRect(back), rect);
      expect(find.byType(AppDockIconButton), findsOneWidget);
      final fade = find
          .descendant(of: back, matching: find.byType(FadeTransition))
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    }
  });

  testWidgets('departing panes stay in place and new panes fade with icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onArchive: () {})),
    );
    final archive = find.byKey(const ValueKey('dock-action-archive'));
    final before = tester.getRect(archive);
    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onRemove: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(archive), before);
    final paneFade = find.descendant(
      of: find.byKey(const ValueKey('dock-pane-secondary')),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(paneFade).opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(archive, findsNothing);
    expect(find.byKey(const ValueKey('dock-pane-secondary')), findsNothing);

    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onArchive: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final iconFade = find
        .descendant(of: archive, matching: find.byType(FadeTransition))
        .first;
    expect(
      tester.widget<FadeTransition>(paneFade).opacity.value,
      tester.widget<FadeTransition>(iconFade).opacity.value,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a newly shown action springs in: larger, smaller, then its '
      'real size — like the view switch bounce', (tester) async {
    await tester.pumpWidget(dockHost(dockConfiguration(onSave: () {})));
    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onRemove: () {})),
    );
    double scale() => tester
        .widget<ScaleTransition>(
          find
              .descendant(
                of: find.byKey(const ValueKey('dock-action-remove')),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;
    final scales = <double>[];
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      scales.add(scale());
    }
    final peak = scales.reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1));
    expect(
      scales.sublist(scales.indexOf(peak)).reduce((a, b) => a < b ? a : b),
      lessThan(1),
    );
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  testWidgets('a leaving action submerges: swells larger first, then '
      'shrinks away and fades', (tester) async {
    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onRemove: () {})),
    );
    await tester.pumpWidget(dockHost(dockConfiguration(onSave: () {})));
    ScaleTransition scale() => tester.widget<ScaleTransition>(
      find
          .descendant(
            of: find.byKey(const ValueKey('dock-action-remove')),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    final scales = <double>[];
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byKey(const ValueKey('dock-action-remove')).evaluate().isEmpty) {
        break;
      }
      scales.add(scale().scale.value);
    }
    expect(scales.reduce((a, b) => a > b ? a : b), greaterThan(1));
    expect(scales.last, lessThan(1));
    await tester.pumpAndSettle();
  });
}
