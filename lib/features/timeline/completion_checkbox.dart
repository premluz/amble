import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/haptics.dart';
import '../../core/tokens/semantic_theme.dart';

/// Animated Noto emoji shown briefly over the checkbox on completion — one
/// picked at random per tap, per direct request, so repeat completions
/// don't feel identical. Real animated Lottie files from Google's Noto
/// emoji animation set (googlefonts.github.io/noto-emoji-animation),
/// bundled locally under `assets/celebrations/` rather than fetched from
/// Google's CDN at runtime — confirmed via AskUserQuestion (bundle vs.
/// live-fetch) after the user explicitly authorized adding a new
/// dependency (`lottie`) for this, overriding the earlier decision to use
/// plain static Unicode emoji instead. See docs/DECISIONS.md.
///
/// Source codepoints (matching the user's own list): clap (u1f44f_1f3fc),
/// trophy (u1f3c6), gold medal (u1f947), direct hit (u1f3af), drum
/// (u1f941), chequered flag (u1f3c1), muscle (u1f4aa_1f3fc), glowing star
/// (u1f31f) — fetched once from
/// `https://fonts.gstatic.com/s/e/notoemoji/latest/{codepoint}/lottie.json`
/// and committed as static assets.
const _celebrationAssets = [
  'assets/celebrations/clap.json',
  'assets/celebrations/trophy.json',
  'assets/celebrations/gold_medal.json',
  'assets/celebrations/direct_hit.json',
  'assets/celebrations/drum.json',
  'assets/celebrations/chequered_flag.json',
  'assets/celebrations/muscle.json',
  'assets/celebrations/glowing_star.json',
];

/// The Timeline task block's completion control — a small ring on the far
/// right of the row, filled with a checkmark when done. Moved here from an
/// on-badge tap per direct request: the badge/title area is now purely a
/// tap-to-edit zone, and this is the only way to toggle completion inline.
///
/// The visible ring is small (24px) but the tap target is padded out to
/// [AmbleTheme.spacingMinTapTarget] (48px) — a visually small control still
/// needs a full-size hit area per Material Design/WCAG 2.5.8 minimum
/// target-size guidance, confirmed directly rather than assumed.
class CompletionCheckbox extends StatefulWidget {
  const CompletionCheckbox({
    super.key,
    required this.theme,
    this.ringColor,
    required this.isCompleted,
    required this.onToggle,
    this.useMutedCompletedColor = false,
    this.haptics = const PlatformHaptics(),
  });

  final AmbleTheme theme;

  /// Injected rather than read from a provider, matching `AppSwitch` and
  /// `AppPressFeedback` — several Timeline tests pump the blocks that own
  /// this checkbox without a `ProviderScope`.
  final Haptics haptics;

  /// The ring's border color while unchecked, and its fill color while
  /// checked — unless [useMutedCompletedColor] overrides the checked case.
  /// Null (the default for every real caller) uses
  /// [AmbleTheme.colorTextSecondary] — a fixed, category-independent
  /// color. Reversed directly from an earlier "always the category color"
  /// design: the checkbox reported as reading like a second category
  /// indicator when it changed color per task; completion status should
  /// look the same regardless of what's being completed. Still overridable
  /// per call site (kept, not removed) in case a future caller genuinely
  /// needs a different fixed color — just no call site passes a
  /// category-derived one any more.
  final Color? ringColor;
  final bool isCompleted;
  final VoidCallback? onToggle;

  /// When true AND [isCompleted], the checked ring fills with
  /// [AmbleTheme.colorTextSecondary] (the same grey a completed task's own
  /// title text uses) instead of [ringColor] — now the same color
  /// [ringColor]'s own default already resolves to, so this flag is a
  /// no-op for every current caller (all of which now rely on that
  /// default) but is kept for a caller that explicitly overrides
  /// [ringColor] to something else and still wants the completed fill to
  /// go muted-grey specifically.
  final bool useMutedCompletedColor;

  @override
  State<CompletionCheckbox> createState() => _CompletionCheckboxState();
}

class _CompletionCheckboxState extends State<CompletionCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late Animation<double> _fadeOpacity;
  String? _celebrationAsset;
  int _celebrationPlayCount = 0;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    // Controls the celebration's OPACITY (fade-in, hold, fade-out) — the
    // Lottie animation itself plays independently on its own internal
    // timeline once mounted, via Lottie.asset's own controller. This one
    // only decides how long the (already-animating) emoji stays visible,
    // composed from the existing motionNormal/motionSlow tokens rather
    // than a new one-off duration for the whole sequence.
    final fadeIn = widget.theme.motionNormal;
    final hold = widget.theme.motionSlow;
    final fadeOut = widget.theme.motionNormal;
    final total = fadeIn + hold + fadeOut;

    _fadeController = AnimationController(vsync: this, duration: total);
    _fadeOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: fadeIn.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: hold.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: fadeOut.inMilliseconds.toDouble(),
      ),
    ]).animate(_fadeController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final wasCompleted = widget.isCompleted;
    // Asymmetric on purpose, for the same reason the celebration below is:
    // finishing something earns the heavier `success`, while undoing it
    // gets the plain `selection` tick — an undo is a correction, not an
    // achievement, and should not feel like one.
    widget.haptics.play(
      wasCompleted ? AmbleHaptic.selection : AmbleHaptic.success,
    );
    widget.onToggle?.call();
    // Celebration only plays on the completing tap, not on un-completing —
    // confirmed via AskUserQuestion rather than assumed; celebrating an
    // undo would read wrong.
    if (!wasCompleted) {
      setState(() {
        _celebrationAsset =
            _celebrationAssets[_random.nextInt(_celebrationAssets.length)];
        _celebrationPlayCount++;
      });
      _fadeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    // Requested directly ("size of checkbox to 18px from 20") — a
    // dedicated literal, not `theme.spacingLg` (24px, still used
    // elsewhere for unrelated spacing), since the checkbox's own visual
    // ring size is a distinct design decision from the generic spacing
    // scale. The 48px tap target below is unaffected — only the visible
    // ring shrinks.
    const ringDiameter = 18.0;
    final ringColor = widget.ringColor ?? theme.colorTextSecondary;
    final checkedFillColor = widget.useMutedCompletedColor
        ? theme.colorTextSecondary
        : ringColor;

    return GestureDetector(
      onTap: widget.onToggle == null ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: theme.spacingMinTapTarget,
        height: theme.spacingMinTapTarget,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Crossfades against the celebration below: driven by the same
            // _fadeOpacity as its inverse (1 - value), so the ring fades
            // out exactly as the Lottie fades in, and fades back in exactly
            // as the Lottie fades out at the end — one shared animation
            // clock, so the two can't drift out of sync with each other.
            AnimatedBuilder(
              animation: _fadeOpacity,
              builder: (context, child) =>
                  Opacity(opacity: 1 - _fadeOpacity.value, child: child),
              child: Container(
                width: ringDiameter,
                height: ringDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isCompleted ? checkedFillColor : null,
                  border: widget.isCompleted
                      ? null
                      : Border.all(
                          color: ringColor,
                          width: theme.borderWidthHairline,
                        ),
                ),
                child: widget.isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: ringDiameter * 0.7,
                        color: theme.colorSurfacePrimary,
                      )
                    : null,
              ),
            ),
            // Fades in over the checkbox, holds, then fades out — by the
            // time it's gone the checkbox underneath is already showing
            // its filled/checked state, per direct request ("when fade
            // out see checkbox ticked"). The Lottie animation plays once
            // (no repeat) and is sized generously beyond the ring itself
            // so the emoji reads clearly rather than being cropped to the
            // checkbox's own small footprint.
            if (_celebrationAsset != null)
              AnimatedBuilder(
                animation: _fadeOpacity,
                builder: (context, child) =>
                    Opacity(opacity: _fadeOpacity.value, child: child),
                child: SizedBox(
                  width: theme.spacingMinTapTarget,
                  height: theme.spacingMinTapTarget,
                  // Keyed on play count (not just the asset path) so a
                  // repeat pick of the same celebration still gets a fresh
                  // Lottie widget/AnimationController — without this,
                  // Flutter reuses the existing element for an unchanged
                  // asset path and the already-finished internal animation
                  // never replays, even though the fade (driven separately
                  // by _fadeController) still runs every time.
                  child: Lottie.asset(
                    _celebrationAsset!,
                    key: ValueKey(_celebrationPlayCount),
                    repeat: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
