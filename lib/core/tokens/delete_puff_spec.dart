import 'package:flutter/painting.dart';

/// Fixed geometry and sampling constants from the exported puff formula.
abstract final class DeletePuffMotionTokens {
  static const referenceObjectWidth = 136.0;
  static const firstBirth = .09;
  static const angleJitter = .26;
  static const radialStart = 15.0;
  static const radialRandomBase = .85;
  static const radialRandomSpan = .3;
  static const verticalRadialRatio = .72;
  static const sizeRandomBase = .65;
  static const sizeRandomSpan = .55;
  static const sizeFadeStart = .2;
  static const sizeFadeSpan = .8;
  static const sizeFadeAmount = .84;
  static const lobeCount = 5;
  static const lobeXRatio = .57;
  static const lobeYRatio = .38;
  static const lobeRadiusBase = .57;
  static const lobeRadiusSpan = .22;
  static const lobeHeightRatio = .78;
  static const clusterRotation = 30.0;
  static const rotationDrift = 35.0;
  static const fadeInFraction = .11;
  static const shadowOffsetRatio = .16;
  static const highlightOffsetRatio = .13;
  static const highlightWidthRatio = .84;
  static const highlightHeightRatio = .44;
  static const seedMultiplier = 71.3;
  static const laneMultiplier = 127.1;
  static const randomScale = 43758.5453;
  static const highlightLobeIndices = [3, 4];
}

/// Exported delete-puff controls from `rios-motion-v19/delete-puff-config.json`.
class DeletePuffSpec {
  const DeletePuffSpec({
    this.durationSeconds = 1.25,
    this.count = 11,
    this.spread = 104,
    this.lift = 34,
    this.size = 22,
    this.curl = 22,
    this.stagger = .27,
    this.fadeStart = .325,
    this.scale = .85,
    this.seed = 15,
    this.smokeColor = const Color(0xFFEDEBE5),
    this.shadowColor = const Color(0xFFA9A498),
    this.highlightColor = const Color(0xFFFFFFFF),
  }) : assert(durationSeconds > 0),
       assert(count >= 0),
       assert(spread >= 0),
       assert(lift >= 0),
       assert(size >= 0),
       assert(curl >= 0),
       assert(stagger >= 0 && stagger <= 1),
       assert(fadeStart >= 0 && fadeStart <= 1),
       assert(scale >= 0);

  final double durationSeconds;
  final int count;
  final double spread;
  final double lift;
  final double size;
  final double curl;
  final double stagger;
  final double fadeStart;
  final double scale;
  final int seed;
  final Color smokeColor;
  final Color shadowColor;
  final Color highlightColor;

  Duration get duration => Duration(
    microseconds: (durationSeconds * Duration.microsecondsPerSecond).round(),
  );
}
