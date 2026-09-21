import 'package:flutter/material.dart';

/// Vertically centres a Timeline block's title column against the BADGE
/// beside it, rather than against however tall the block's own row or
/// duration-scaled pill happens to be.
///
/// Extracted 2026-09-21 as genuinely shared structure, requested directly
/// after an imported event's title read visibly higher than a native
/// task's beside it on device: "the solution must be so that the
/// code/classes are shared those of native, then we should achieve the
/// correct position." `TaskCapsuleBlock` and `ExternalEventCapsuleBlock`
/// had each grown their OWN vertical-centring wrapper — the task's went
/// through three measured-wrong combinators before landing on the one
/// below, while the event's stayed on a simpler
/// `ConstrainedBox(minHeight:) + Center` that measured identically in the
/// widget-test harness but did not agree with it on a real device. Two
/// independently-written implementations of one rule is what allowed that
/// drift; this is the one implementation both now call.
///
/// [headerHeight] is the height to centre WITHIN — a badge's own size, or
/// (for a real task) whichever of the pill height / minimum tap target
/// governs, capped so a multi-hour pill never drags its title away from
/// the icon pinned at the pill's top.
///
/// The combinator needs TWO boxes doing two different jobs, and three
/// simpler shapes were each measured wrong before this one (kept here
/// because every one of them looks correct at a glance):
///
/// 1. A bare `Center` against the parent's full height — a stretched row
///    passes its REAL height down (often a trailing checkbox's 48px tap
///    target, or a duration-scaled pill), so the title drifts far from
///    the icon (measured 38px off at 90 minutes, 105.5px at 180).
/// 2. `Align` + `ConstrainedBox(minHeight: headerHeight)` — a MINIMUM can
///    only ever GROW to what the parent already offers, never shrink it,
///    so this silently behaves identically to (1).
/// 3. `OverflowBox(minHeight:/maxHeight: headerHeight)` directly around
///    the child — `OverflowBox`'s own min/max still constrain the CHILD's
///    layout (only PAINT escapes the parent's box), so a `maxHeight`
///    reintroduces a RenderFlex overflow on a two-line title, and a
///    `minHeight` alone stretches a SHORT single-line title to fill
///    [headerHeight] instead of centring within it.
///
/// What actually measures right:
/// - An outer `OverflowBox` with NO min/max of its own (0/infinity) —
///   this is what decouples the alignment region from the parent's
///   height, letting it size to whatever its own child needs.
/// - An inner `ConstrainedBox(minHeight: headerHeight)` wrapping an
///   `Align` — which gives ITS child loose (not tight) constraints, so a
///   short title keeps its natural size and centres within the floor,
///   while a taller two-line column simply exceeds that floor and sizes
///   itself, unclipped, with the outer `OverflowBox` growing to match.
///
/// `Alignment.centerLeft`, never a bare `Center`: only the VERTICAL half
/// was ever wanted. A `Center` anchors both axes, which went unnoticed
/// while the column always had a wide child — but with icons hidden and
/// the time line empty, the column shrank to the title alone and that
/// title floated to the horizontal centre (measured at title.left 275.6
/// against every other row kind's 72.0).
///
/// [shrinkWrapWidth] is the one thing callers legitimately differ on, so
/// it stays a parameter rather than being baked in — see its own doc
/// comment.
class CapsuleTitleAlignment extends StatelessWidget {
  const CapsuleTitleAlignment({
    super.key,
    required this.headerHeight,
    required this.child,
    this.shrinkWrapWidth = true,
    this.escapesBoundedParentHeight = true,
  });

  /// The height to vertically centre [child] within — see the class doc
  /// comment. Callers pass their badge's own size, or a capped pill
  /// height, never the full row height.
  final double headerHeight;

  /// Whether this sizes its own WIDTH to [child] (`widthFactor: 1`) or
  /// keeps filling whatever width the parent offers.
  ///
  /// True (the default) for `TaskCapsuleBlock`, whose column already sits
  /// inside a `Flexible` with a real `maxWidth` — there, shrink-wrapping
  /// is what keeps a title-only column from floating to the horizontal
  /// centre. False for `ExternalEventCapsuleBlock`, whose text column is
  /// positioned between an explicit `textColumnLeft`/`textColumnRight`
  /// pair and MUST keep filling that span so its title truncates at the
  /// same x every native task's does; shrink-wrapping there loses the
  /// width bound entirely and overflows.
  final bool shrinkWrapWidth;

  /// Whether the parent hands down a BOUNDED height this needs to escape.
  ///
  /// True (the default) for `TaskCapsuleBlock`, whose column sits inside a
  /// stretched Row that passes its full height down — the `OverflowBox`
  /// is what decouples the alignment region from that height, and without
  /// it the title drifts with the pill (the whole bug this widget exists
  /// to prevent).
  ///
  /// False for `ExternalEventCapsuleBlock`, which positions this inside a
  /// `Positioned` carrying only top/left/right, so the incoming height is
  /// ALREADY unbounded. There the `OverflowBox` has nothing to escape and
  /// actively breaks: asked to be as big as possible under an unbounded
  /// constraint it resolves to an infinite size and throws
  /// ("RenderConstrainedOverflowBox object was given an infinite size
  /// during layout").
  ///
  /// A caller flag rather than a `LayoutBuilder` probing `constraints
  /// .hasBoundedHeight`: `LayoutBuilder` sizes ITSELF to the incoming
  /// constraints, which re-imposes exactly the parent height the
  /// `OverflowBox` is there to escape — measured, and it broke the
  /// native task's own alignment tests.
  final bool escapesBoundedParentHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = ConstrainedBox(
      constraints: BoxConstraints(minHeight: headerHeight),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: shrinkWrapWidth ? 1 : null,
        heightFactor: 1,
        child: child,
      ),
    );

    if (!escapesBoundedParentHeight) return aligned;

    return OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: aligned,
    );
  }
}
