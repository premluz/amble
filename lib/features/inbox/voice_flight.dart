import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/tokens/depth_motion_spec.dart';
import '../../core/tokens/voice_mode_tokens.dart';
import '../../core/widgets/app_depth.dart';
import '../../core/widgets/app_modal_scope.dart';

part 'voice_flight.g.dart';

/// Opens voice mode over everything (the root navigator, above the shell's
/// toolbar). The route itself only supplies the timing and keeps the page
/// visible behind: the screen choreographs its own entrance and exit from
/// the route animation (the glow rising and sinking, the toolbar morphing
/// out of and back into the mic), while its tasks fly into their Inbox rows.
Future<void> pushVoiceModeRoute(BuildContext context, WidgetBuilder builder) {
  final rootBuilder = rootModalBuilder(context, builder);
  final still = MediaQuery.disableAnimationsOf(context);
  final sweeps = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(voiceModeSweepProvider.notifier);
  final route = PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: still ? Duration.zero : VoiceModeTokens.enterDuration,
    reverseTransitionDuration: still
        ? Duration.zero
        : VoiceModeTokens.exitDuration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        rootBuilder(context),
  );
  final closed = Navigator.of(context, rootNavigator: true).push<void>(route);
  final animation = route.animation;
  if (animation == null) {
    throw StateError('Voice mode route was pushed without an animation');
  }
  sweeps.follow(animation);
  return closed;
}

/// The page under voice mode sweeps away from the bottom as the screen
/// covers it, and returns as it uncovers ([AppSweepFade]). Null while voice
/// mode is not open.
@Riverpod(keepAlive: true)
class VoiceModeSweep extends _$VoiceModeSweep {
  @override
  Animation<double>? build() => null;

  /// Follows [route] until it is fully dismissed: the sweep runs with the
  /// screen's own scrim (covering on entry, revealing early on exit).
  void follow(Animation<double> route) {
    final sweep = CurvedAnimation(
      parent: route,
      curve: const Interval(0, VoiceModeTokens.scrimShare),
      // Back early on exit, with the scrim and the toolbar.
      reverseCurve: const Interval(1 - VoiceModeTokens.revealShare, 1),
    );
    void settle(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      route.removeStatusListener(settle);
      if (state == sweep) state = null;
      sweep.dispose();
    }

    route.addStatusListener(settle);
    state = sweep;
  }
}

/// Shared hero tag between a voice-mode segment and the Inbox row its task
/// became, so the task flies from one to the other as voice mode closes.
Object voiceFlightTag(String taskId) => ('voice-flight', taskId);

/// Inbox task ids arriving by flight from voice mode. Their rows open their
/// space as usual; their entrance happens in flight instead (the card flies
/// in while its pill emerges, see [voiceFlightShuttle]).
@Riverpod(keepAlive: true)
class VoiceArrivals extends _$VoiceArrivals {
  @override
  Set<String> build() => const {};

  void land(Iterable<String> taskIds) => state = Set.unmodifiable(taskIds);
}

/// The path a flying task takes, starting [index] steps after the first so
/// several tasks land one after another rather than all at once.
CreateRectTween voiceFlightTween(int index) {
  final delay = _flightDelay(index);
  return (begin, end) =>
      _StaggeredRectTween(begin: begin, end: end, delay: delay);
}

/// Share of the exit before task [index] sets off.
double _flightDelay(int index) => math.min(
  index * VoiceModeTokens.flightStagger,
  VoiceModeTokens.flightMaxDelay,
);

class _StaggeredRectTween extends RectTween {
  _StaggeredRectTween({super.begin, super.end, required this.delay});

  final double delay;

  @override
  Rect? lerp(double t) =>
      // Lands by [VoiceModeTokens.flightLandShare], then rests in its row.
      super.lerp(
        Interval(
          delay,
          VoiceModeTokens.flightLandShare,
          curve: Curves.easeInOutCubic,
        ).transform(t),
      );
}

/// Flies task [index]'s destination row content, on a transparent Material
/// so its text keeps its real style mid-flight. Its pill emerges from depth
/// on the way, exactly as a typed task's does (small and transparent,
/// larger, smaller, actual), over that task's own staggered flight; its
/// text, already on screen in voice mode, just flies.
HeroFlightShuttleBuilder voiceFlightShuttle(int index) {
  final delay = _flightDelay(index);
  return (flightContext, animation, direction, fromHeroContext, toHeroContext) {
    final pop = direction == HeroFlightDirection.pop;
    final hero = pop ? toHeroContext.widget : fromHeroContext.widget;
    if (hero is! Hero) {
      throw StateError('Voice flight shuttle built for a non-Hero: $hero');
    }
    // On a pop the route animation runs 1 → 0; the flight runs 0 → 1.
    final flight = pop ? ReverseAnimation(animation) : animation;
    return Material(
      type: MaterialType.transparency,
      child: AppDepthScope(
        emergence: flight.drive(
          CurveTween(curve: Interval(delay, VoiceModeTokens.flightLandShare)),
        ),
        spec: DepthMotionSpec.standard,
        fadeText: false,
        child: hero.child,
      ),
    );
  };
}
