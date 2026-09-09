import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';

/// Shared fade widget extracted 2026-09-08 after the Timeline's own top
/// scroll-fade turned out to be missing from Inbox, Tracked, and every
/// modal sheet header — requested directly: "cant see that 'shade' top
/// on headers (inbox, tracked..) and modal headers."
void main() {
  Future<void> pump(
    WidgetTester tester, {
    double? height,
    bool fromBottom = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: AppTopScrollFade(
            color: AmbleTheme.light.colorSurfaceTimeline,
            height: height,
            fromBottom: fromBottom,
          ),
        ),
      ),
    );
  }

  testWidgets('fades from the given color at the TOP to fully transparent '
      'by default', (tester) async {
    await pump(tester);

    final decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
            as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors.first, AmbleTheme.light.colorSurfaceTimeline);
    expect(gradient.colors.last.a, 0);
  });

  // Requested directly: "use same at the bottom" — every surface with a
  // top fade got a mirrored bottom one.
  testWidgets('fromBottom: true flips the gradient so the colour sits at '
      'the BOTTOM instead, fading to transparent going up', (tester) async {
    await pump(tester, fromBottom: true);

    final decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
            as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(gradient.begin, Alignment.bottomCenter);
    expect(gradient.end, Alignment.topCenter);
    expect(gradient.colors.first, AmbleTheme.light.colorSurfaceTimeline);
    expect(gradient.colors.last.a, 0);
  });

  testWidgets('is wrapped in IgnorePointer — purely decorative, must '
      'never intercept a tap meant for content scrolled underneath', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.ancestor(
        of: find.byType(DecoratedBox),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    final ignorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(DecoratedBox),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('defaults to spacingXl * 2 tall — deliberately UN-linked from '
      'spacingContentTop (the separate content-top-padding value), '
      'reported directly after briefly matching it read as too short, '
      'especially on the Timeline', (tester) async {
    await pump(tester);

    final size = tester.getSize(find.byType(AppTopScrollFade));
    expect(size.height, AmbleTheme.light.spacingXl * 2);
  });

  testWidgets('an explicit height overrides the default', (tester) async {
    await pump(tester, height: 50);

    final size = tester.getSize(find.byType(AppTopScrollFade));
    expect(size.height, 50);
  });
}
