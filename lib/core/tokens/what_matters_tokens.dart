/// Coordinated attention motion; all phases are fractions of the entrance.
abstract final class WhatMattersTokens {
  static const enter = Duration(milliseconds: 800);
  static const leave = Duration(milliseconds: 550);
  static const releaseStart = 1 / 6;
  static const releaseEnd = 13 / 18;
  static const collapseStart = 7 / 18;
  static const collapseEnd = 17 / 18;
  static const laneSettleStart = releaseEnd;
  static const returnStart = 1 / 6;
  static const returnRevealEnd = 5 / 6;
  static const scaleLoss = .025;
  static const washAlphaLight = .14;
  static const washAlphaDark = .12;
  // Originally bumped from .03/.04 to .11/.09 to match
  // AmbleTheme.colorSurfaceWhatMatters' own blend ratio — requested
  // directly: the lens needs a "big alpha" tint so it reads as clearly
  // distinct from the ordinary Timeline, not the previous barely-visible
  // wash. Light bumped again to .20, requested directly a second time
  // ("on light mode make it stronger") — dark's own .09 is unchanged,
  // only light was called out. Kept as separate alpha constants rather
  // than read from the token itself, because this painter animates the
  // tint in/out via `amount`, multiplying against a bare alpha value —
  // painting this wash over `colorSurfaceTimeline` at full `amount` is
  // the same visible result as `colorSurfaceWhatMatters` itself (both are
  // the same accent-over-base blend at the same ratio), so no separate
  // background-color branch is needed at the Timeline's own call site.
  // `colorSurfaceWhatMatters` exists as a reusable flat token for any
  // OTHER surface that wants the resting tint without this animated
  // painter — kept in sync with these two values, see its own doc
  // comment in semantic_theme.dart.
  static const tintAlphaLight = .20;
  static const tintAlphaDark = .09;
  static const buttonAlphaLight = .12;
  static const buttonAlphaDark = .16;
  static const rippleWidth = .35;
}
