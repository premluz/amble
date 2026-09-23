import 'dart:io';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_boundary_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/load_app_fonts.dart';

/// Reported directly from a device screenshot: "the timeline on the left
/// should be left line because currently it overlaps."
///
/// The hour labels right-align inside a fixed column that ends exactly
/// where the task pills begin, so a label wider than its column does not
/// clip — it paints straight into the pill column. At the old 56px width
/// the two-digit-hour labels ("11:00 AM", "12:00 PM") measured 57.6 and
/// did precisely that, while single-digit hours ("1:00 PM", 50.4) fit and
/// looked fine — which is why only the 10-12 o'clock rows collided.
void main() {
  setUpAll(loadAppFonts);

  /// **2026-09-23 — reads the time column directly, not derived from a
  /// composite.** Column 1 (`AmbleTheme.spacingTimeColumnWidth`) IS the
  /// label column now — under the three-column contract it has its own
  /// fixed width rather than being "whatever's left of a combined gutter
  /// after the side inset," so there is nothing left to compute here. See
  /// `TimelineColumns`' own doc comment in `semantic_theme.dart` and
  /// `test/core/tokens/timeline_columns_test.dart` for the contract this
  /// file's own numbers now come from.
  final screenPadding = AmbleTheme.light.spacingTimelineGutter;
  final gutterWidth = AmbleTheme.light.spacingTimeColumnWidth;

  Future<Map<String, ({double box, double intrinsic})>> measure(
    WidgetTester tester, {
    required double columnWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              TaskBoundaryMarkers(
                // 11:00 and 12:00 are the widest labels of the day and the
                // ones actually reported as overlapping.
                rangeStart: DateTime(2026, 9, 12, 11, 0),
                rangeEnd: DateTime(2026, 9, 12, 15, 0),
                pixelsPerMinute: 1.2,
                leftInset: screenPadding,
                columnWidth: columnWidth,
              ),
            ],
          ),
        ),
      ),
    );

    final result = <String, ({double box, double intrinsic})>{};
    for (final element in find.byType(Text).evaluate()) {
      final text = element.widget as Text;
      final painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
      )..layout();
      result[text.data!] = (
        box: tester.getRect(find.byWidget(text)).width,
        intrinsic: painter.width,
      );
    }
    return result;
  }

  testWidgets('no hour label overflows the gutter into the pill column', (
    tester,
  ) async {
    final measured = await measure(tester, columnWidth: gutterWidth);

    expect(measured, isNotEmpty);
    for (final entry in measured.entries) {
      expect(
        entry.value.intrinsic,
        lessThanOrEqualTo(entry.value.box),
        reason:
            '"${entry.key}" needs ${entry.value.intrinsic}px but its column '
            'is only ${entry.value.box}px. The column ends exactly where '
            'task pills start, so the excess paints under the pills.',
      );
    }
  });

  testWidgets('every label keeps a real gap before the pill column', (
    tester,
  ) async {
    final measured = await measure(tester, columnWidth: gutterWidth);

    // A label that merely *fits* is still touching the pills. The widest
    // one should leave visible separation, not land flush against them.
    final widest = measured.values
        .map((m) => m.intrinsic)
        .reduce((a, b) => a > b ? a : b);
    expect(
      gutterWidth - widest,
      greaterThanOrEqualTo(8.0),
      reason: 'widest label is ${widest}px in a ${gutterWidth}px gutter',
    );
  });

  // **2026-09-21 — this guard is no longer needed and is gone.** It read
  // a private constant out of `timeline_screen.dart` to catch this file's
  // own hardcoded copy going stale. Both are now replaced by the shared
  // `AmbleTheme` column tokens, which this file reads directly — so there
  // is nothing left to fall out of sync, and
  // `horizontal_spacing_system_test.dart`/`timeline_columns_test.dart` own
  // the equivalent cross-view/cross-width checks.

  testWidgets('the old 56px gutter genuinely overflowed — the reported bug', (
    tester,
  ) async {
    final measured = await measure(tester, columnWidth: 56.0);

    // Pins the actual defect so the fix cannot be quietly reverted, and
    // documents which labels were and were not affected.
    expect(measured['11:00 AM']!.intrinsic, greaterThan(56.0));
    expect(measured['12:00 PM']!.intrinsic, greaterThan(56.0));
    expect(measured['1:00 PM']!.intrinsic, lessThan(56.0));
  });

  /// Reported directly: "time on timeline still not left aligned ...
  /// these should have same padding as zone names on the other side."
  ///
  /// The screen must NOT pass `columnWidth`, since that is what switches
  /// these labels to right-aligned. Asserted by reading the call site,
  /// because the alignment is decided there rather than inside the widget.
  test('the Timeline left-aligns its hour labels, mirroring zone names', () {
    final source = File('lib/features/timeline/timeline_screen.dart')
        .readAsStringSync();

    final call = RegExp(
      r'TaskBoundaryMarkers\((.*?)\),\n',
      dotAll: true,
    ).firstMatch(source);
    expect(call, isNotNull, reason: 'TaskBoundaryMarkers call site not found');

    final args = call!.group(1)!;
    expect(
      args.contains('columnWidth:'),
      isFalse,
      reason: 'columnWidth right-aligns the labels; the screen must omit it',
    );
    // **2026-09-23 — reads `theme.timelineTimeLeft` explicitly.** Column
    // 1's own left edge under the three-column contract — see
    // `TimelineColumns`' own doc comment. Scoped to just the Timeline; the
    // Weekly Zone Authoring Grid's own axis lives in a fixed, tightly-sized
    // 60px gutter that stays at its own 8px, unaffected by this contract.
    expect(
      args.contains('leftInset: theme.timelineTimeLeft'),
      isTrue,
      reason:
          'the hour gutter must read theme.timelineTimeLeft, the Timeline\'s '
          'own column-1 edge token',
    );
  });

  /// Reported directly, TWICE now (this exact class of bug already once
  /// before, in the opposite direction — see this file's own git history):
  /// "current hour not aligned with day hours on timeline." `TaskBoundary
  /// Markers` and `CurrentTimeIndicator` are two separate widgets sharing
  /// ONE visual column — each hardcodes its own `leftInset` at its own
  /// call site rather than reading a shared constant, so nothing stops
  /// the two from silently drifting apart again the next time either one
  /// changes alone. Reads both call sites directly, the same "keep the
  /// source honest" pattern the rest of this file already uses, so a
  /// future edit to just one of them fails loudly here instead of
  /// shipping a visible misalignment.
  test('TaskBoundaryMarkers and CurrentTimeIndicator share the SAME '
      'leftInset — they render in one shared hour-gutter column', () {
    final source = File('lib/features/timeline/timeline_screen.dart')
        .readAsStringSync();

    final markersIndex = source.indexOf('TaskBoundaryMarkers(');
    final indicatorIndex = source.indexOf('CurrentTimeIndicator(');
    expect(
      markersIndex,
      isNot(-1),
      reason: 'TaskBoundaryMarkers call site not found',
    );
    expect(
      indicatorIndex,
      isNot(-1),
      reason: 'CurrentTimeIndicator call site not found',
    );

    // `leftInset:` is a non-comment code line at both call sites — matching
    // straight from each widget's own start (rather than `(.*?)\),\n`, which
    // can stop early at an unrelated `),` inside a doc comment before ever
    // reaching the real closing paren) is what keeps this test honest.
    String? leftInsetAfter(int index) => RegExp(
      r'^\s*leftInset:\s*(\S+?),\s*$',
      multiLine: true,
    ).firstMatch(source.substring(index, index + 2500))?.group(1);

    final markersLeftInset = leftInsetAfter(markersIndex);
    final indicatorLeftInset = leftInsetAfter(indicatorIndex);

    expect(markersLeftInset, isNotNull);
    expect(
      indicatorLeftInset,
      markersLeftInset,
      reason:
          'CurrentTimeIndicator\'s leftInset (currently '
          '$indicatorLeftInset) must match TaskBoundaryMarkers\' own '
          '(currently $markersLeftInset) — otherwise "now" visibly '
          'fails to line up with the hour ticks beside it',
    );
  });
}
