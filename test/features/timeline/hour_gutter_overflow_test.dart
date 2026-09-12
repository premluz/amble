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

  /// The production values: `_hourGutterWidth` and `spacingScreenPadding`
  /// from `timeline_screen.dart`. Kept in sync by the guard test below.
  const gutterWidth = 72.0;
  const screenPadding = 28.0;

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

  test('the width these tests assert against matches production', () {
    // `_hourGutterWidth` is private, so it cannot be imported. Reading the
    // source keeps this file honest: widen the real gutter without
    // updating `gutterWidth` above and this fails loudly, rather than the
    // overflow tests silently passing against a stale number.
    final source = File('lib/features/timeline/timeline_screen.dart')
        .readAsStringSync();
    final match = RegExp(r'const _hourGutterWidth = ([\d.]+);')
        .firstMatch(source);

    expect(match, isNotNull, reason: '_hourGutterWidth declaration not found');
    expect(double.parse(match!.group(1)!), gutterWidth);
  });

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
    expect(
      args.contains('leftInset: theme.spacingScreenPadding'),
      isTrue,
      reason: 'labels must sit at the same inset the zone names use',
    );
  });
}
