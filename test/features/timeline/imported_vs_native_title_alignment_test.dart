import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/dev_config.dart' show TimelineTaskTextLayout;
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';

/// Reported directly, repeatedly, from device screenshots with a
/// centre-line drawn through each block's icon: an imported event's title
/// sits LOWER than its own calendar badge's centre, while a native task's
/// title sits correctly centred on its circle badge.
///
/// Each block already has its own single-widget alignment test
/// (`external_event_capsule_layout_test.dart`,
/// `task_capsule_title_alignment_test.dart`) and BOTH pass — each measures
/// its own block in isolation against its own badge. That is exactly the
/// gap this file closes: the bug is only visible when the two are compared
/// against EACH OTHER, which no existing test did.
void main() {
  final theme = AmbleTheme.light;
  final rangeStart = DateTime(2026, 9, 21, 8);

  /// Both blocks share these, so any difference the test finds is the
  /// blocks' own, not the harness's.
  const left = 56.0;
  const textColumnLeft = 90.0;
  const textColumnRight = 16.0;
  const pixelsPerMinute = 1.5;

  /// The title-centre-minus-icon-centre offset for one block kind, at a
  /// given duration. Zero means "the title is level with its icon."
  Future<double> measureOffset(
    WidgetTester tester, {
    required bool imported,
    required int durationMinutes,
  }) async {
    final start = DateTime(2026, 9, 21, 9);
    final end = start.add(Duration(minutes: durationMinutes));

    final Widget block = imported
        ? ExternalEventCapsuleBlock(
            theme: theme,
            event: ExternalCalendarEvent(
              id: 'evt-1',
              title: 'Workshop',
              start: start,
              end: end,
              sourceCalendarId: 'cal-1',
            ),
            rangeStart: rangeStart,
            pixelsPerMinute: pixelsPerMinute,
            left: left,
            columnOffset: 0,
            textColumnLeft: textColumnLeft,
            textColumnRight: textColumnRight,
            // Production defaults — see the matching note on the native
            // block below.
            durationVisible: false,
          )
        : TaskCapsuleBlock(
            // The layout the REAL spatial view renders: `timeline_screen
            // .dart` passes `devTextLayout`, whose own default is
            // `inline` (see `DevTimelineTaskTextLayout`). This widget's
            // own constructor still defaults to `stacked`, so leaving it
            // unset here measures a two-line column no production screen
            // actually shows — and a two-line column legitimately sits
            // its TITLE above centre, which would make this test chase a
            // difference that is not the reported one.
            textLayout: TimelineTaskTextLayout.inline,
            // Production defaults: `DevTimelineTaskDurationVisible` and
            // `DevTimelineTaskTimeRangeVisible` both build() to false, and
            // `timeline_screen.dart` passes them straight through — so the
            // real spatial view renders a TITLE-ONLY row for both block
            // kinds. Both constructors default these to true, which would
            // otherwise measure a row production never shows.
            durationVisible: false,
            timeRangeVisible: false,
            task: Task.create(
              title: 'Workshop',
              scheduledAt: start,
              durationMinutes: durationMinutes,
              categoryId: BuiltInCategoryIds.work,
            ),
            category: Category(
              id: BuiltInCategoryIds.work,
              name: 'Work',
              colorToken: 0,
              emoji: '💼',
              isBuiltIn: true,
            ),
          );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Stack(children: [imported ? block : Positioned(child: block)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.getRect(find.byType(Icon).first);
    // `findRichText: true` — the inline layout renders title (and time)
    // as one `Text.rich`, which a plain `find.text` never matches.
    final title = tester.getRect(
      find.textContaining('Workshop', findRichText: true).first,
    );
    return title.center.dy - icon.center.dy;
  }

  // Reported repeatedly from device screenshots, and the last real
  // difference between the two blocks: the native title renders at w700
  // while the imported one used the plain title style's regular weight.
  // Different weights carry different vertical metrics inside the same
  // line box, so the glyphs sit at different heights even when the boxes
  // measure identically — which is exactly what made this so hard to see
  // from the widget tests alone.
  //
  // The muted COLOUR stays different on purpose (an imported event must
  // never read as an editable Amble object); only the weight is shared.
  testWidgets('an imported event\'s title renders at the SAME font weight as a '
      'native task\'s, while keeping its own muted colour', (tester) async {
    final theme = AmbleTheme.light;
    final start = DateTime(2026, 9, 21, 9);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Stack(
            children: [
              ExternalEventCapsuleBlock(
                theme: theme,
                event: ExternalCalendarEvent(
                  id: 'evt-1',
                  title: 'Workshop',
                  start: start,
                  end: start.add(const Duration(minutes: 30)),
                  sourceCalendarId: 'cal-1',
                ),
                rangeStart: rangeStart,
                pixelsPerMinute: pixelsPerMinute,
                left: left,
                columnOffset: 0,
                textColumnLeft: textColumnLeft,
                textColumnRight: textColumnRight,
                durationVisible: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // `findRichText: true` matches the inner `RichText`, not the `Text`
    // wrapper — so the resolved span is read straight off it.
    final title = tester.widget<RichText>(
      find.textContaining('Workshop', findRichText: true).first,
    );
    // The style that actually paints the title's glyphs. `RichText.text`
    // is the ROOT span, whose own style is the ambient `DefaultTextStyle`
    // the tree merged in — not what this widget set. The title's own
    // style lives on the span carrying the text, so walk to it rather
    // than reading the root and measuring the wrong thing.
    TextStyle? paintedTitleStyle;
    title.text.visitChildren((span) {
      if (span is TextSpan && (span.text?.contains('Workshop') ?? false)) {
        paintedTitleStyle = span.style;
        return false;
      }
      return true;
    });
    final span = paintedTitleStyle != null
        ? TextSpan(style: paintedTitleStyle)
        : title.text as TextSpan;

    expect(
      span.style?.fontWeight,
      FontWeight.w700,
      reason:
          'the imported title must carry the same w700 a native task\'s '
          'does — a lighter weight sits differently in the line box and '
          'reads as misaligned beside it',
    );
    expect(
      span.style?.color,
      theme.colorTextSecondary,
      reason:
          'the muted colour is the deliberate read-only distinction and '
          'must survive the weight match',
    );
  });

  testWidgets(
    'an imported event\'s title sits at the SAME offset from its own icon '
    'as a native task\'s title does from its own — the two block kinds '
    'must read identically side by side',
    (tester) async {
      for (final durationMinutes in [30, 90]) {
        final importedOffset = await measureOffset(
          tester,
          imported: true,
          durationMinutes: durationMinutes,
        );
        final nativeOffset = await measureOffset(
          tester,
          imported: false,
          durationMinutes: durationMinutes,
        );

        expect(
          importedOffset,
          moreOrLessEquals(nativeOffset, epsilon: 1.0),
          reason:
              'at ${durationMinutes}m an imported event\'s title sat '
              '${importedOffset}px from its icon centre while a native '
              'task\'s sat ${nativeOffset}px from its own — they must '
              'match, or the two read as misaligned beside each other',
        );
      }
    },
  );
}
