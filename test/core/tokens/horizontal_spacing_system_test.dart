import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_boundary_markers.dart';
import 'package:amble/features/timeline/zone_container_block.dart';

/// The app has exactly TWO horizontal measurements, and every screen is
/// meant to derive from them rather than carry its own copy:
///
/// - `spacingScreenPadding` — screen edge to page content, everywhere
///   (top nav, settings gear, page titles, list rows, AND the Timeline's
///   hour labels in both views).
/// - `spacingHourGutter` — screen edge to Timeline CONTENT (a task pill,
///   a zone card), leaving the hour labels the space between.
///
/// Requested directly after a screenshot marked the intended inset down
/// both screen edges and showed the nav, the calendar and the timeline's
/// hours each landing somewhere different: "we need a coherent system
/// that can manage this spacing without drift."
///
/// Drift is the specific failure this file exists to catch. Two of the
/// values below are top-level `const`s in the non-spatial Zone view,
/// which cannot read the theme — so nothing in the type system stops them
/// from disagreeing with the tokens the spatial view uses for the exact
/// same distances. That is not hypothetical: `zoneContentLeftInset` was
/// an independent hardcoded `90` matching the spatial view only by
/// coincidence, and the two silently came apart the moment the page inset
/// changed.
void main() {
  final light = AmbleTheme.light;
  final dark = AmbleTheme.dark;

  test('both themes agree on the two horizontal measurements', () {
    // A per-theme side inset would mean the page's left edge MOVED when
    // the user switched theme, which is never intended.
    expect(light.spacingScreenPadding, dark.spacingScreenPadding);
    expect(light.spacingHourGutter, dark.spacingHourGutter);
  });

  test('the non-spatial hour label sits at spacingScreenPadding, the same '
      'inset the spatial view gives its own hour labels', () {
    expect(
      zoneRowTimeLabelEdgeInset,
      light.spacingScreenPadding,
      reason:
          'zoneRowTimeLabelEdgeInset ($zoneRowTimeLabelEdgeInset) is the '
          'non-spatial view\'s hour-label inset; the spatial view passes '
          'spacingScreenPadding (${light.spacingScreenPadding}) for the '
          'same distance. They must match or the hour visibly jumps '
          'between the two views.',
    );
  });

  test('the non-spatial content inset equals spacingHourGutter, the same '
      'distance the spatial view puts its task pills at', () {
    expect(
      zoneContentLeftInset,
      light.spacingHourGutter,
      reason:
          'zoneContentLeftInset ($zoneContentLeftInset) is where a zone '
          'card starts; spacingHourGutter (${light.spacingHourGutter}) '
          'is where a task pill starts. They are the same measurement '
          'and must not drift.',
    );
  });

  test('the hour gutter leaves real room for a label beside the content', () {
    // The label column is what remains after the side inset. The widest
    // label of the day ("12:00 AM") measures 57.6px at the app's own type
    // scale, and `hour_gutter_overflow_test.dart` requires >= 8px of
    // clearance so a label can never paint into the pill column — a rule
    // written from a real reported overlap.
    const widestLabelWidth = 57.6;
    final labelColumn = light.spacingHourGutter - light.spacingScreenPadding;

    expect(
      labelColumn - widestLabelWidth,
      greaterThanOrEqualTo(8.0),
      reason:
          'the label column is ${labelColumn}px '
          '(spacingHourGutter ${light.spacingHourGutter} - '
          'spacingScreenPadding ${light.spacingScreenPadding}), which '
          'leaves only ${labelColumn - widestLabelWidth}px beside the '
          'widest label',
    );
  });

  testWidgets('the hour label TEXT renders at spacingScreenPadding in both '
      'views — the same painted x, not just the same box origin', (
    tester,
  ) async {
    // The check that was missing, and the reason an 8px gap survived
    // three rounds of inspection: every existing test compared the values
    // passed IN (`leftInset`, `zoneRowTimeLabelEdgeInset`) and those
    // already agreed. What differed was what each widget did with that box
    // afterwards — `TaskBoundaryMarkers` padded its text a further
    // `spacingSm` inside it, so identical inputs produced hour labels 8px
    // apart on screen. Measuring the painted `Text` is the only way to see
    // that.
    Future<double> textLeftOf(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [light]),
          home: Scaffold(body: Stack(children: [child])),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(Text).first).left;
    }

    final spatialTextLeft = await textLeftOf(
      TaskBoundaryMarkers(
        rangeStart: DateTime(2026, 9, 21, 9),
        rangeEnd: DateTime(2026, 9, 21, 10),
        pixelsPerMinute: 1.5,
        leftInset: light.spacingScreenPadding,
      ),
    );

    // `leftPaddingToEscape: 0` — this label reaches its own absolute x by
    // escaping backwards through however much padding it is nested in;
    // with none, it lands on `zoneRowTimeLabelEdgeInset` directly, which
    // is the position under test.
    final nonSpatialTextLeft = await textLeftOf(
      ZoneRowTimeLabel(
        theme: light,
        text: '9:00 AM',
        leftPaddingToEscape: 0,
        reservedWidth: zoneRowTimeLabelReservedWidth,
      ),
    );

    expect(
      spatialTextLeft,
      moreOrLessEquals(light.spacingScreenPadding, epsilon: 0.5),
      reason:
          'the spatial view\'s hour text painted at ${spatialTextLeft}px, '
          'not the shared ${light.spacingScreenPadding}px inset',
    );
    expect(
      nonSpatialTextLeft,
      moreOrLessEquals(spatialTextLeft, epsilon: 0.5),
      reason:
          'the non-spatial view\'s hour text painted at '
          '${nonSpatialTextLeft}px against the spatial view\'s '
          '${spatialTextLeft}px — the hour visibly jumps between views',
    );
  });

  test('the spatial Timeline derives its gutter from the token, not its own '
      'arithmetic', () {
    // Read from source: the regression being guarded is a call site
    // reintroducing a local `66 + spacingScreenPadding`-style
    // expression, which is precisely how the two views drifted before.
    final source = File('lib/features/timeline/timeline_screen.dart')
        .readAsStringSync();

    expect(
      source.contains('theme.spacingHourGutter'),
      isTrue,
      reason:
          'timeline_screen.dart must read spacingHourGutter rather than '
          'rebuilding the gutter from a local constant',
    );
    expect(
      RegExp(r'const _hourGutterWidth = [\d.]+;').hasMatch(source),
      isFalse,
      reason:
          'the private _hourGutterWidth constant is what the token '
          'replaced; reintroducing it re-opens the drift',
    );
  });
}
