/// Voice mode's choreography. Entering: the page dims, a layered glow rises
/// from the bottom and the mic's pane morphs into the voice toolbar. Leaving:
/// the toolbar morphs back into the mic, the glow sinks, and each task it
/// created flies into its Inbox row, one after another. Times are seconds;
/// the rest are fractions of the transition.
abstract final class VoiceModeTokens {
  static const enterSeconds = .7;
  static const exitSeconds = .8;

  /// The page behind is covered within this first share of the entrance.
  static const scrimShare = .5;

  /// On exit the page is fully back within this first share: the scrim
  /// lifts, the glow sinks and the page's rows sweep back, in step with the
  /// toolbar returning into the mic (home at `AppPaneMorph.returnEnd`, i.e.
  /// after 1 − .55 = 45% of the exit).
  static const revealShare = .45;

  /// Flying tasks have landed in their rows by this share of the exit.
  static const flightLandShare = .8;

  /// The close button, status card and transcript are gone within this
  /// first share of the exit (and arrive in the last share of the entrance).
  static const controlsExitShare = .45;

  /// Each later task starts its flight this much later…
  static const flightStagger = .09;

  /// …capped so the last one still has time to land.
  static const flightMaxDelay = .45;

  /// The glow reaches this share of the screen's height from the bottom;
  /// above it the screen stays clean.
  static const glowReach = .75;

  /// One full drift cycle of the glow's layers.
  static const glowDriftSeconds = 18.0;

  /// Colour stops of every glow layer: full at the base, this share of
  /// the layer's alpha at [glowMidStop], nothing at its rim.
  static const glowMidStop = .45;
  static const glowMidAlphaShare = .45;

  /// How far the deep and light tones lean from the accent toward the page
  /// and toward the primary text.
  static const glowDeepMix = .35;
  static const glowLightMix = .4;

  /// The glow's layers, back to front: a wide deep base, two drifting
  /// accent/light lobes, and a bright core low in the centre. Sizes are
  /// shares of the screen width ([width]) and of the reach ([height]).
  static const glowLayers = <VoiceGlowLayer>[
    (tone: VoiceGlowTone.deep, x: .5, width: 1.1, height: 1, alpha: .7),
    (tone: VoiceGlowTone.accent, x: .26, width: .75, height: .85, alpha: .5),
    (tone: VoiceGlowTone.light, x: .76, width: .65, height: .7, alpha: .4),
    (tone: VoiceGlowTone.light, x: .5, width: .5, height: .32, alpha: .45),
  ];

  /// Horizontal drift of the lobes, as a share of the screen width, and
  /// their breathing, as a share of their height.
  static const glowDriftX = .07;
  static const glowBreathe = .08;

  /// The waveform's bars rise in one after another, left to right, each on
  /// its own bouncy spring (up, past, back) like a run of piano keys. They
  /// start once the toolbar pane has stretched enough to show its content.
  static const keysDelaySeconds = .12;
  static const keyStaggerSeconds = .018;
  static const keySpringSeconds = .38;
  static const keyBounce = .55;

  static Duration get keysDelay => _seconds(keysDelaySeconds);

  static Duration get enterDuration => _seconds(enterSeconds);
  static Duration get exitDuration => _seconds(exitSeconds);
  static Duration get glowDriftDuration => _seconds(glowDriftSeconds);

  static Duration _seconds(double s) =>
      Duration(microseconds: (s * Duration.microsecondsPerSecond).round());
}

enum VoiceGlowTone { deep, accent, light }

typedef VoiceGlowLayer = ({
  VoiceGlowTone tone,
  double x,
  double width,
  double height,
  double alpha,
});
