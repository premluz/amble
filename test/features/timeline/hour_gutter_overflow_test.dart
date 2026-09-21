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

  /// **2026-09-21 — derived from the tokens, not copied from them.**
  /// These were two hardcoded numbers (66 and 28) meant to mirror
  /// production, and both had already gone stale: production's side inset
  /// was 24 at the time, not 28. That is the same copy-drift the whole
  /// horizontal spacing system was just consolidated to prevent
  /// (`horizontal_spacing_system_test.dart`), so this file stops keeping
  /// its own copies too.
  ///
  /// The label column is what remains of [AmbleTheme.spacingHourGutter]
  /// once the side inset is taken off the front — that column is what a
  /// label must fit inside, and what it must never paint out of into the
  /// pill column beyond.
  final screenPadding = AmbleTheme.light.spacingScreenPadding;
  final gutterWidth = AmbleTheme.light.spacingHourGutter - screenPadding;

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
  // the private `_hourGutterWidth` out of `timeline_screen.dart` to catch
  // this file's own hardcoded copy going stale. Both the constant and the
  // copies are now replaced by `AmbleTheme.spacingHourGutter`, which this
  // file reads directly — so there is nothing left to fall out of sync,
  // and `horizontal_spacing_system_test.dart` owns the equivalent
  // cross-view check (including that the constant is not reintroduced).

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
    // **2026-09-21 — back to spacingScreenPadding (24px), superseding the
    // "both 8px, matching the zone grid axis" decision this test used to
    // pin.** Reported directly against a screenshot: the hour labels sat
    // visibly closer to the true screen edge than Day/Inbox/Tracked and
    // the settings gear above them — "day in inbox tracked and settings
    // should have same side padding as hours in timeline (that should be
    // global content padding)." Scoped to just the Timeline, confirmed
    // directly — the Weekly Zone Authoring Grid's own axis lives in a
    // fixed, tightly-sized 60px gutter that can't take a wider inset
    // without real layout work, and stays at its own 8px for now.
    expect(
      args.contains('leftInset: theme.spacingScreenPadding'),
      isTrue,
      reason:
          'the hour gutter must match spacingScreenPadding (24px), the '
          'same inset Day/Inbox/Tracked and every other screen uses',
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
