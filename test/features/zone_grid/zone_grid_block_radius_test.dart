import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/selected_pill_border.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  final theme = AmbleTheme.light;
  final zone = Zone(
    id: 'radius-zone',
    title: 'Focus',
    startMinutes: 60,
    endMinutes: 180,
    weekday: 1,
  );

  Future<void> pumpBlock(
    WidgetTester tester, {
    bool selected = false,
    bool ghost = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ZoneGridBlock(
                  theme: theme,
                  zone: zone,
                  top: 20,
                  height: 100,
                  isSelected: selected,
                  dayColumnLeft: 0,
                  moveGhostOffset: ghost ? const Offset(0, 8) : null,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saved, selected, and move-ghost shapes share radiusMd', (
    tester,
  ) async {
    await pumpBlock(tester);
    final shape = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('zone-grid-block-shape-radius-zone')),
    );
    expect(
      (shape.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(theme.radiusMd),
    );

    await pumpBlock(tester, selected: true);
    final selection = tester.widget<SelectedPillBorder>(
      find.byType(SelectedPillBorder),
    );
    expect(selection.contentRadius, BorderRadius.circular(theme.radiusMd));

    await pumpBlock(tester, ghost: true);
    final ghostShape = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('zone-move-ghost-shape-radius-zone')),
    );
    expect(
      (ghostShape.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(theme.radiusMd),
    );
  });
}
