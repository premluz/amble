import 'package:amble/core/tokens/liquid_pulse_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_liquid_pulse.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Selecting a zone bounces the whole block — fill, ring and resize
/// handles as one piece — with the gentler large-surface spec, and never
/// while the block is under a finger.
void main() {
  final theme = AmbleTheme.light;
  final zone = Zone(
    id: 'pulse-zone',
    title: 'Focus',
    startMinutes: 60,
    endMinutes: 180,
    weekday: 1,
  );

  Future<void> pumpBlock(
    WidgetTester tester, {
    required bool selected,
    int? liveStartMinutes,
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
                  liveStartMinutes: liveStartMinutes,
                  onTap: () {},
                  onResizeTopEnd: (_) {},
                  onResizeBottomEnd: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double scaleY(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(AppLiquidPulse),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .storage[5];

  testWidgets('selecting bounces the block with its handles inside, gently', (
    tester,
  ) async {
    await pumpBlock(tester, selected: false);
    await pumpBlock(tester, selected: true);

    final pulse = tester.widget<AppLiquidPulse>(find.byType(AppLiquidPulse));
    expect(pulse.spec, LiquidPulseSpec.selectSurface);
    expect(
      find.descendant(
        of: find.byType(AppLiquidPulse),
        matching: find.byType(ResizeHandle),
      ),
      findsNWidgets(2),
      reason: 'handles move with the block, not float beside it',
    );

    await tester.pump(LiquidPulseSpec.selectSurface.compressDuration);
    expect(
      scaleY(tester),
      closeTo(1 - LiquidPulseSpec.selectSurface.depth, .002),
    );
    await tester.pumpAndSettle();
    expect(scaleY(tester), 1);
  });

  testWidgets('no bounce while the block is being moved or resized', (
    tester,
  ) async {
    await pumpBlock(tester, selected: false, liveStartMinutes: 60);
    await pumpBlock(tester, selected: true, liveStartMinutes: 60);
    await tester.pump(LiquidPulseSpec.selectSurface.compressDuration);
    expect(scaleY(tester), 1);
  });
}
