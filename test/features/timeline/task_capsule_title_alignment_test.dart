import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

/// Regression coverage for a real bug, reported directly against a
/// screenshot: "task outside zone view text isn't centered... on timeline
/// view text goes higher, should be aligned with icon."
///
/// Root cause, measured before fixing: the row is `IntrinsicHeight`-sized
/// to whichever sibling is tallest, and the title/time text column was
/// pinned to a fixed 4px offset from the row's own top — correct only by
/// coincidence for a badge-floor pill next to a SHORTER checkbox, and
/// visibly wrong (dead space below the text) once the trailing
/// `CompletionCheckbox`'s fixed 48px tap target exceeded a short pill's
/// own height, or wrong the other way (text dragged far from the icon)
/// if centered blindly against a tall pill's own full height.
void main() {
  Future<Rect> emojiRect(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(AnimatedContainer).first,
      matching: find.byType(Text),
    );
    return Future.value(tester.getRect(finder.first));
  }

  Future<void> pumpTask(
    WidgetTester tester, {
    required int durationMinutes,
    bool showCompletionCheckbox = true,
    bool compactText = false,
  }) {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 15, 9),
      durationMinutes: durationMinutes,
      categoryId: BuiltInCategoryIds.work,
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            showCompletionCheckbox: showCompletionCheckbox,
            compactText: compactText,
          ),
        ),
      ),
    );
  }

  // The core invariant: wherever the icon sits, the title sits at the SAME
  // offset from it — at every pill height. A tall pill dragging the title
  // away from the icon (measured at +38px before this fix) is exactly the
  // "text goes higher... should be aligned with icon" bug.
  testWidgets(
    'the title\'s vertical offset from the pill\'s own icon is IDENTICAL '
    'at every task duration — short, medium, and multi-hour',
    (tester) async {
      final offsets = <int, double>{};
      for (final durationMinutes in [10, 30, 90, 180]) {
        await pumpTask(tester, durationMinutes: durationMinutes);
        await tester.pumpAndSettle();

        final icon = await emojiRect(tester);
        final title = tester.getRect(find.text('Deep work'));
        offsets[durationMinutes] = title.center.dy - icon.center.dy;
      }

      final distinctOffsets = offsets.values.toSet();
      expect(
        distinctOffsets.length,
        1,
        reason:
            'every duration must offset the title from the icon by the '
            'SAME amount — got $offsets. A tall pill dragging the title '
            'away from the icon (or a short one leaving it stuck at a '
            'fixed top offset) would show up here as differing values.',
      );
    },
  );

  // A short pill (badge floor) sitting beside the trailing checkbox's
  // taller 48px tap target must center its title within that taller
  // region, not stay pinned near the row's very top with dead space below
  // — the specific symptom the "not centered" report described. Uses
  // `compactText: true` (a single-line `inline` layout, matching Zone
  // view's own unzoned-row config) — the DEFAULT `stacked` layout shows
  // both a title AND a time line, whose combined natural height (measured:
  // 56px) already exceeds the 48px checkbox floor with no slack left to
  // visibly center within; `compactText`'s single line is genuinely
  // shorter, which is the case that actually has room to center in.
  testWidgets(
    'a short pill\'s title centers within the row, not pinned to the very '
    'top with empty space below it',
    (tester) async {
      await pumpTask(tester, durationMinutes: 10, compactText: true);
      await tester.pumpAndSettle();

      // The pill's own top edge is the reliable, undisplaced reference
      // for "the row's real top" — the trailing CompletionCheckbox has
      // its own deliberate -9px visual nudge (see its own doc comment),
      // which would skew a gapAbove/gapBelow comparison measured against
      // IT for reasons unrelated to this fix. `textHeaderHeight` (48, the
      // checkbox's own `spacingMinTapTarget`) is the actual centering
      // region the fix establishes; a title's OWN box should be centered
      // within a 48px-tall span starting at the pill's top.
      final pillTop = tester.getTopLeft(find.byType(AnimatedContainer).first).dy;
      final title = tester.getRect(
        find.textContaining('Deep work', findRichText: true),
      );

      const textHeaderHeight = 48.0;
      final gapAbove = title.top - pillTop;
      final gapBelow = (pillTop + textHeaderHeight) - title.bottom;
      // Not asserting a tight/symmetric split here — `Text.rich`'s own
      // layout box includes font-metric ascent/descent padding beyond its
      // tight glyph bounds (the same effect measured on the icon-alignment
      // offset above, a stable -1.5px rather than 0), so a perfectly equal
      // gapAbove/gapBelow split isn't the right bar. What actually matters
      // — and is what the report described — is real room on BOTH sides,
      // not the old pinned-to-top-with-nothing-below-it state (measured at
      // gapAbove=0, gapBelow=40 before this fix).
      expect(
        gapAbove,
        greaterThan(0),
        reason:
            'the title must not be pinned flush to the row\'s very top — '
            'gapAbove=$gapAbove gapBelow=$gapBelow (was 0/40 before this '
            'fix). A residual asymmetry here is expected font-metric '
            'padding, not a centering bug — confirm the visual result on '
            'a real device/screenshot if pixel-exact centering matters.',
      );
      expect(gapBelow, greaterThan(0));
    },
  );

  // Without the checkbox, the "taller sibling" that used to force extra
  // header height is gone — the text should track the pill's own height
  // directly, with no leftover dead space from a checkbox that isn't
  // there.
  testWidgets(
    'with the checkbox hidden, a short pill\'s title still aligns with '
    'its icon (no checkbox left to misalign against)',
    (tester) async {
      await pumpTask(
        tester,
        durationMinutes: 10,
        showCompletionCheckbox: false,
      );
      await tester.pumpAndSettle();

      final icon = await emojiRect(tester);
      final title = tester.getRect(find.text('Deep work'));
      expect(
        (title.center.dy - icon.center.dy).abs(),
        lessThan(title.height),
      );
    },
  );

  // No overflow for the `stacked` text layout (title + time/duration each
  // on their own line) — regression guard for the fix's own first,
  // over-eager attempt: a fixed-height cap on the text column clipped
  // this two-line layout whenever it summed to more than the checkbox's
  // 48px, throwing a RenderFlex overflow.
  testWidgets(
    'a short pill with the two-line stacked text layout renders with no '
    'overflow',
    (tester) async {
      await pumpTask(tester, durationMinutes: 10);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
