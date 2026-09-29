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
  // Optional persistent surface tint ratios, kept in sync with
  // AmbleTheme.colorSurfaceWhatMatters. WhatMattersScene no longer paints
  // this flat tint over the page; its accent feedback is a transient ripple.
  static const tintAlphaLight = .20;
  static const tintAlphaDark = .09;
  static const buttonAlphaLight = .12;
  static const buttonAlphaDark = .16;
  static const rippleWidth = .35;

  /// The persistent "mode is on" glow: a soft radial bloom rising from the
  /// bottom centre (where the What Matters toolbar button sits), under all
  /// content. Low and quiet on purpose, unlike voice mode's large bloom.
  static const glowAlphaLight = .22;
  static const glowAlphaDark = .26;

  /// Radius as a fraction of the page's shortest side (its width).
  static const glowRadius = 1.1;

  /// Where the glow has fallen to [glowMidAlphaShare] of its peak.
  static const glowMidStop = .45;
  static const glowMidAlphaShare = .5;
}
