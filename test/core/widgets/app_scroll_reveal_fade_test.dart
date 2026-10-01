import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_scroll_reveal_fade.dart';

void main() {
  testWidgets('hidden at rest, shown once scrolled by its own height', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final theme = AmbleTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Stack(
          children: [
            ListView(
              controller: controller,
              children: [for (var i = 0; i < 50; i++) Text('Row $i')],
            ),
            AppScrollRevealFade(controller: controller, color: Colors.white),
          ],
        ),
      ),
    );
    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    expect(opacity(), 0);
    controller.jumpTo(theme.spacingXl / 2);
    await tester.pump();
    expect(opacity(), closeTo(.5, .01));
    controller.jumpTo(theme.spacingXl * 3);
    await tester.pump();
    expect(opacity(), 1);
  });
}
