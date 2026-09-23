import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reported directly, with a reference screenshot marking the intended
/// checkbox position with a red line: on Task (spatial) view, a task
/// row's checkbox used to stop 48px from the screen edge whenever zones
/// existed (24px `rightEdgeInset` + 24px reserved so the rotated
/// zone-name label could never render underneath it) versus 24px with no
/// zones — a real, visible difference in checkbox position depending on
/// zone presence. Fixed: the checkbox column no longer widens for zones;
/// the zone-name label (an `IgnorePointer`, so it can't steal taps) shares
/// that same outer margin instead of pushing the checkbox column inward.
///
/// **Then narrowed further**, on a second direct request: even at the
/// standard `rightEdgeInset` (24px, the same margin every other screen
/// uses), there was still "room to the right" specifically on this
/// column — confirmed as "the 24px margin itself is too generous here
/// specifically," not the shared page margin. The checkbox column was
/// given its own `textColumnRightInset` (`spacingMd`, 16px at the time),
/// while `rightEdgeInset` stayed unchanged for pill positioning and the
/// drag-lift frosted pane, which were never part of either report.
///
/// **2026-09-23 — real bug, fixed.** `textColumnRightInset` is
/// page-absolute at every call site (`ExternalEventCapsuleBlock`,
/// `_DraggablePendingTaskPill`, the overlap-cluster row) EXCEPT
/// `_DraggableTaskBlock`'s own text row, which nests inside a box already
/// positioned at `rightEdgeInset`. That one call site was stacking
/// `textColumnRightInset` on TOP of the outer `rightEdgeInset`, landing
/// the checkbox at `rightEdgeInset + spacingMd` from the true edge instead
/// of the intended single inset — reported directly, again, as too much
/// space on the right in spatial view specifically. Fixed by reverting
/// `textColumnRightInset` back to the page-absolute `spacingScreenPadding`
/// (matching every OTHER call site's own coordinate space) and hardcoding
/// `0` at `_DraggableTaskBlock`'s own nested text-row `Positioned.right`
/// instead, since that box's outer `rightEdgeInset` already reaches the
/// true edge.
///
/// Tested by reading the source rather than rendering a full Timeline:
/// the composition itself is what both fixes changed, and a full render
/// would need a real Hive+ProviderScope+seeded-zones harness to exercise
/// a code path this guard already pins directly.
void main() {
  final source = File('lib/features/timeline/timeline_screen.dart')
      .readAsStringSync();

  test('the dead zone-label-gutter helper was removed, not left unused', () {
    expect(
      source.contains('_zoneLabelGutterWidth'),
      isFalse,
      reason:
          'the helper that widened textColumnRight for zones should be '
          'gone entirely now that nothing calls it',
    );
  });

  test('no textColumnRight/right assignment still widens for zones', () {
    // Matches a composed expression like `rightEdgeInset + something` or
    // `textColumnRightInset + something` — the zone-conditional
    // widening this fix removed, in either its old or new base value.
    final badComposition = RegExp(
      r'(textColumnRight|right):\s*\n?\s*(rightEdgeInset|textColumnRightInset)\s*\+',
    );
    expect(
      badComposition.hasMatch(source),
      isFalse,
      reason:
          'found a right-inset still ADDING to a base value — the '
          'zone-conditional widening should be gone',
    );
  });

  test(
    'textColumnRightInset is page-absolute again, matching rightEdgeInset',
    () {
      expect(
        source.contains(
          'final textColumnRightInset = theme.spacingScreenPadding;',
        ),
        isTrue,
        reason:
            'textColumnRightInset must be page-absolute — every call site '
            'except _DraggableTaskBlock\'s own nested text row measures it '
            'from the true screen edge, not from an already-inset box',
      );

      // Every page-absolute call site (3x textColumnRight, 1x the
      // overlap-cluster's own `right:`) should use this value.
      expect(
        'textColumnRight: textColumnRightInset,'.allMatches(source).length,
        3,
        reason: 'expected exactly 3 plain-task/pending-draft call sites',
      );
      expect(
        source.contains('right: textColumnRightInset,'),
        isTrue,
        reason: 'the overlap-cluster row should use the same page-absolute '
            'inset',
      );
    },
  );

  test(
    "_DraggableTaskBlock's own nested text row uses a hardcoded 0, not "
    'textColumnRightInset',
    () {
      // That text row sits inside a box already positioned at
      // `right: widget.rightInset` (== rightEdgeInset) — a SECOND inset
      // here would stack on top of it. See this file's own class doc
      // comment for the exact bug this guards against.
      expect(
        source.contains('right: 0,\n            child: TaskCapsuleTextRow('),
        isTrue,
        reason:
            'the nested text row must use a bare 0, not widget.textColumnRight',
      );
    },
  );

  test('pill positioning and the drag-lift pane still use the wider rightEdgeInset', () {
    // These were never part of either report — narrowing the checkbox
    // column must not have accidentally narrowed pill/drag geometry too.
    expect(
      RegExp(r'rightInset:\s*\n?\s*rightEdgeInset,').hasMatch(source),
      isTrue,
      reason:
          '_DraggableTaskBlock.rightInset should still use the standard '
          'page margin, unaffected by the checkbox-column narrowing',
    );
  });
}
