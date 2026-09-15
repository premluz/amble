import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_step_scaffold.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';

/// Covers two things added directly, together, on 2026-09-08: every
/// StepScaffold-based sheet (task create/edit, templates, zones, tracked
/// behaviors, the category modal) gained a top scroll-fade over its own
/// body, and the header strip itself grew taller. "cant see that 'shade'
/// top on headers (inbox, tracked..) and modal headers (new tamplete,
/// new task)."
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(
    WidgetTester tester, {
    String? modalTitle,
    Widget? headerContent,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: StepScaffold(
          theme: theme,
          headerColor: theme.colorAccent,
          modalTitle: modalTitle,
          headerContent: headerContent,
          onBack: null,
          onClose: () {},
          primaryLabel: 'Done',
          onPrimaryPressed: () {},
          body: const SizedBox(
            width: double.infinity,
            height: 2000,
            child: ColoredBox(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a mirrored bottom scroll-fade above the primary-button '
      'footer, blending from the body\'s own colorSurfaceOverlay', (
    tester,
  ) async {
    await pump(tester, modalTitle: 'New task');

    final bottomFade = find.byWidgetPredicate(
      (w) => w is AppTopScrollFade && w.fromBottom,
    );
    expect(bottomFade, findsOneWidget);
    final fade = tester.widget<AppTopScrollFade>(bottomFade);
    // Sheets moved from level 0 (`colorSurfaceBase`, the literal app
    // background) up to the elevation ramp's top rung — requested
    // directly, "sheets across the app should have next surface level to
    // bg." This fade has to keep matching the body it blends into.
    expect(fade.color, theme.colorSurfaceOverlay);
  });

  // Reported directly (2026-09-09), after the header/body seam still cut
  // scrolling content with a hard edge despite the header's OWN gradient:
  // "the header on pages like Tasks...is not a smooth gradient. The
  // content slides through underneath, and the header cuts the content
  // with a hard edge." The header's gradient only ever blends ITS OWN
  // fixed background into the body's own surface — it says nothing about the
  // body's real scrolling content, which had no fade at all until now.
  testWidgets(
    'shows a TOP scroll-fade at the header/body seam, over the scrolling '
    'body content — for the plain-title header only',
    (tester) async {
      await pump(tester, modalTitle: 'New task');

      final topFade = find.byWidgetPredicate(
        (w) => w is AppTopScrollFade && !w.fromBottom,
      );
      expect(topFade, findsOneWidget);
      final fade = tester.widget<AppTopScrollFade>(topFade);
      // See the bottom-fade test above — the sheet body is now
      // `colorSurfaceOverlay`, and this fade tracks it.
      expect(fade.color, theme.colorSurfaceOverlay);
    },
  );

  testWidgets(
    'the top scroll-fade is omitted for a colored headerContent banner — '
    'a floating panel, not something body content should blend into',
    (tester) async {
      await pump(tester, headerContent: const Text('Zone'));

      final topFade = find.byWidgetPredicate(
        (w) => w is AppTopScrollFade && !w.fromBottom,
      );
      expect(topFade, findsNothing);
    },
  );

  testWidgets('the title header\'s own background IS a gradient — '
      'colorSurfaceSecondary at the top blending down into the body\'s '
      'colorSurfaceOverlay at the header\'s bottom edge — rather than a flat '
      'fill with a separate (and, against an identical fill underneath '
      'it, invisible) fade painted on top. Reported directly: "heading '
      'not have nice gradient... sheet heading section different color '
      'than body."', (tester) async {
    await pump(tester, modalTitle: 'New task');

    final headerContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('New task'), matching: find.byType(Container))
          .first,
    );
    final decoration = headerContainer.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    // The lower stop tracks the sheet BODY's own surface, which moved from
    // level 0 to the elevation ramp's top rung — requested directly,
    // "sheets across the app should have next surface level to bg." The
    // gradient's whole job is fading the header into the body, so a stale
    // stop here would recreate the very report this test's name quotes.
    expect(gradient.colors, [
      theme.colorSurfaceSecondary,
      theme.colorSurfaceOverlay,
    ]);
  });

  testWidgets(
    'a colored headerContent banner gets a flat headerColor fill, not '
    'the plain-title header\'s gradient — a banner has no scrollable '
    'content behind it to blend into',
    (tester) async {
      await pump(tester, headerContent: const Text('Custom header'));

      final headerContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Custom header'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = headerContainer.decoration! as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, theme.colorAccent);

      // Only the bottom (body) fade remains — no header fade at all now
      // that the header's own background is the gradient.
      expect(find.byType(AppTopScrollFade), findsOneWidget);
      expect(
        tester
            .widget<AppTopScrollFade>(find.byType(AppTopScrollFade))
            .fromBottom,
        isTrue,
      );
    },
  );

  testWidgets(
    'the title-bearing header strip is spacingXl + spacingXl + spacingLg '
    'tall',
    (tester) async {
      await pump(tester, modalTitle: 'New template');

      // The header Container is the first ancestor of the title Text
      // sized by the height formula under test — found by its fixed
      // (non-null) height, which only the header strip itself sets.
      final header = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.constraints?.maxHeight != null);
      expect(
        header.constraints!.maxHeight,
        theme.spacingXl + theme.spacingXl + theme.spacingLg,
      );
    },
  );
}
