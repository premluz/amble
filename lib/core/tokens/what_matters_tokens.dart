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
  static const tintAlphaLight = .03;
  static const tintAlphaDark = .04;
  static const buttonAlphaLight = .12;
  static const buttonAlphaDark = .16;
  static const rippleWidth = .35;
}
