import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_dock.dart';
import 'package:amble/core/widgets/app_press_follower.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single-action dock pane IS the visible button, so it swells with its
/// action's press; a multi-action pane stays put while its pressed button
/// swells on its own (Liquid Glass toolbar behaviour).
void main() {
  Widget host() => MaterialApp(
    theme: ThemeData(extensions: [AmbleTheme.light]),
    home: Scaffold(
      body: Center(
        child: AppContextDock(
          configuration: AppContextDockConfiguration(
            stateId: 'press',
            groups: [
              AppContextGroup(
                id: 'solo',
                actions: [
                  AppContextAction(
                    id: 'edit',
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onPressed: () {},
                  ),
                ],
              ),
              AppContextGroup(
                id: 'pair',
                actions: [
                  AppContextAction(
                    id: 'save',
                    icon: Icons.check,
                    tooltip: 'Save',
                    onPressed: () {},
                  ),
                  AppContextAction(
                    id: 'remove',
                    icon: Icons.delete_outline,
                    tooltip: 'Remove',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  double paneScale(WidgetTester tester, String groupId) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.descendant(
                of: find.byKey(ValueKey('dock-pane-$groupId')),
                matching: find.byType(AppPressFollower),
              ),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .storage[5];

  Future<TestGesture> holdOn(WidgetTester tester, String tooltip) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip(tooltip)),
    );
    // Stepped: the button's tap-down waits out the press deadline (its
    // tooltip competes for the pointer), then needs frames to animate.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return gesture;
  }

  testWidgets('holding a lone action swells its whole pane', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(paneScale(tester, 'solo'), 1);

    final gesture = await holdOn(tester, 'Edit');
    expect(paneScale(tester, 'solo'), greaterThan(1.05));
    expect(paneScale(tester, 'pair'), 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(paneScale(tester, 'solo'), 1);
  });

  testWidgets('holding one action of a group leaves the group pane still', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await holdOn(tester, 'Save');
    expect(paneScale(tester, 'pair'), 1);
    final saveScale = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byTooltip('Save'),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[5];
    expect(
      saveScale,
      greaterThan(1.05),
      reason: 'the pressed button still swells on its own',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
