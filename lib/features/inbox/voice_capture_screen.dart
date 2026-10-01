import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/voice_mode_tokens.dart';
import '../../core/widgets/app_depth.dart';
import '../../core/widgets/app_dock_primitives.dart';
import '../../core/widgets/app_pane_morph.dart';
import '../../core/widgets/app_trial_gate.dart';
import '../../core/widgets/app_voice_glow.dart';
import '../../shared/providers/trial_providers.dart';
import 'voice_capture_provider.dart';
import 'voice_capture_screen_parts.dart';
import 'voice_capture_toolbar.dart';
import 'voice_flight.dart';

/// Opens the full-screen "speak your tasks" flow — free speech, split
/// into separate tasks on each natural pause, all added to the Inbox
/// together on Submit. Requested directly, from two wireframes, as an
/// entry point "next to the plus" on the Inbox screen (see
/// `inbox_screen.dart`). [origin] is the global rect of the button it was
/// opened from: the voice toolbar morphs out of it, and back into it.
Future<void> showVoiceCaptureScreen(BuildContext context, {Rect? origin}) {
  return pushVoiceModeRoute(
    context,
    (context) => VoiceCaptureScreen(origin: origin),
  );
}

/// Always renders [AmbleTheme.dark]'s own palette, regardless of the
/// app's current light/dark setting — confirmed directly, matching the
/// reference mock's dark, glowing background on both its listening and
/// paused states. A deliberate "focus mode" look, not a follow-the-
/// system-theme screen like the rest of the app.
///
/// Composes its content from `voice_capture_screen_parts.dart` (the hint,
/// the segment list, the can't-listen card, the pause/resume button) — split
/// out purely to keep this file under CLAUDE.md's 200-line guidance.
class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({
    super.key,
    this.autoStartListening = true,
    this.origin,
  });

  /// The global rect of the pane voice mode was opened from; see
  /// [showVoiceCaptureScreen].
  final Rect? origin;

  /// Whether [initState] calls [VoiceCapture.startListening] on mount.
  /// Defaults true — see [initState]'s own doc comment for the real
  /// product behaviour this drives. Exists as a constructor parameter
  /// (not a `kDebugMode`/`TestWidgetsFlutterBinding` check in the body)
  /// purely for widget tests: `startListening` calls
  /// `SpeechToText.initialize()`, a real platform `MethodChannel` call
  /// with no mock handler registered in this test environment — that
  /// call never completes at all (no error, no timeout), so any test
  /// that pumps this screen without disabling this hangs forever.
  /// `voice_capture_screen_test.dart` passes `false` and drives state
  /// through `VoiceCapture.debugSetCommittedSegments` instead.
  final bool autoStartListening;

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen> {
  /// The lines as submitted, kept on screen (the provider resets on submit)
  /// so each can fly from where it was into its Inbox row.
  List<String>? _submitted;

  /// Per submitted line: the Inbox task it became, or null if scheduled.
  List<String?> _flightIds = const [];

  /// The route's own animation, which drives the whole choreography; and
  /// its curved slices, built once (a CurvedAnimation listens to its
  /// parent). The controls arrive late and leave early; the page behind is
  /// covered early and uncovered late.
  Animation<double> _route = kAlwaysCompleteAnimation;
  CurvedAnimation? _controlsExit;
  CurvedAnimation? _scrimIn;
  CurvedAnimation? _riseIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (_controlsExit != null || routeAnimation == null) return;
    _route = routeAnimation;
    _controlsExit = CurvedAnimation(
      parent: routeAnimation,
      curve: const Interval(1 - VoiceModeTokens.controlsExitShare, 1),
    );
    // On exit the page comes back early, in step with the toolbar
    // returning into the mic, not dragged across the whole exit.
    const reveal = Interval(1 - VoiceModeTokens.revealShare, 1);
    _scrimIn = CurvedAnimation(
      parent: routeAnimation,
      curve: const Interval(0, VoiceModeTokens.scrimShare),
      reverseCurve: reveal,
    );
    _riseIn = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: const Interval(
        1 - VoiceModeTokens.revealShare,
        1,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controlsExit?.dispose();
    _scrimIn?.dispose();
    _riseIn?.dispose();
    super.dispose();
  }

  Animation<double> get _controls => _controlsExit ?? kAlwaysCompleteAnimation;
  Animation<double> get _scrim => _scrimIn ?? kAlwaysCompleteAnimation;
  Animation<double> get _rise => _riseIn ?? kAlwaysCompleteAnimation;

  /// Creates the tasks, then closes onto the Inbox: each Inbox-bound line
  /// is tagged with its task so it flies into its row, one after another.
  Future<void> _submit() async {
    final notifier = ref.read(voiceCaptureProvider.notifier);
    final segments = List.of(ref.read(voiceCaptureProvider).committedSegments);
    List<String?> ids;
    // Same "trial expired -> present the paywall -> retry once" shape as
    // quick_capture_sheet.dart's own _retryAfterPaywallIfExpired.
    try {
      ids = await notifier.submit();
    } on TrialExpiredException {
      if (!mounted) return;
      final unlocked = await presentPaywallForTrialExpired(context, ref);
      if (!unlocked || !mounted) return;
      ids = await notifier.submit();
    }
    if (!mounted) return;
    ref.read(voiceArrivalsProvider.notifier).land(ids.whereType<String>());
    setState(() {
      _submitted = segments;
      _flightIds = ids;
    });
    // Close on the next frame, once the tagged lines are built, so the
    // flights have a source to leave from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Object? _flightTagFor(int index) {
    final id = index < _flightIds.length ? _flightIds[index] : null;
    return id == null ? null : voiceFlightTag(id);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.autoStartListening) return;
    // Starts listening immediately on open — "as you press this record,
    // this full screen comes on and is already in listening mode,"
    // requested directly, so there is no separate "tap to start" step
    // once the screen itself has opened.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(voiceCaptureProvider.notifier).startListening(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.dark;
    final state = ref.watch(voiceCaptureProvider);
    final isSubmitting = state.status == VoiceCaptureStatus.submitting;

    return Theme(
      data: ThemeData(useMaterial3: true, extensions: [theme]),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, box) {
            final (:toolbar, :close) = voiceToolbarLayout(
              theme,
              box.biggest,
              MediaQuery.viewPaddingOf(context),
            );
            // Both panes split out of the mic (and merge back into it).
            // Without a source (no mic on screen), from where the mic
            // usually sits: just left of the "+".
            final origin =
                widget.origin ??
                close.translate(-close.width - theme.spacingMd, 0);
            final mic = Icon(
              Icons.mic_none_rounded,
              color: theme.colorTextSecondary,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: AppVoiceGlow(theme: theme, scrim: _scrim, rise: _rise),
                ),
                SafeArea(child: _content(theme, state, toolbar.height)),
                Positioned.fill(
                  child: AppPaneMorph(
                    theme: theme,
                    animation: _route,
                    forwardSeconds: VoiceModeTokens.enterSeconds,
                    origin: origin,
                    target: close,
                    from: mic,
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacingXs),
                      child: AppDockIconButton(
                        theme: theme,
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        selected: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AppPaneMorph(
                    theme: theme,
                    animation: _route,
                    forwardSeconds: VoiceModeTokens.enterSeconds,
                    origin: origin,
                    target: toolbar,
                    from: mic,
                    child: VoiceCaptureToolbar(
                      theme: theme,
                      // Unavailable offers Resume too: it retries starting.
                      isPaused:
                          state.status == VoiceCaptureStatus.paused ||
                          state.status == VoiceCaptureStatus.unavailable,
                      isListening: state.status == VoiceCaptureStatus.listening,
                      isSubmitting: isSubmitting,
                      soundLevel: state.soundLevel,
                      onPause: () =>
                          ref.read(voiceCaptureProvider.notifier).pause(),
                      onResume: () =>
                          ref.read(voiceCaptureProvider.notifier).resume(),
                      // Disabled until something has been captured —
                      // requested directly ("in listening mode before
                      // anything is said or created, it's disabled").
                      onSubmit: state.canSubmit && !isSubmitting
                          ? _submit
                          : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Everything above the toolbar panes: the transcript, and — only when
  /// listening can't start — the reason, one gap above them.
  Widget _content(AmbleTheme theme, VoiceCaptureState state, double pane) {
    final segments = _submitted != null
        ? VoiceCaptureSegmentList(
            key: const ValueKey('segments'),
            theme: theme,
            segments: _submitted!,
            heroTagFor: _flightTagFor,
          )
        : VoiceCaptureSegmentList(
            key: const ValueKey('segments'),
            theme: theme,
            segments: state.committedSegments,
            partialText: state.partialText,
          );
    final quiet =
        _submitted == null &&
        state.committedSegments.isEmpty &&
        state.partialText.isEmpty;
    return Column(
      children: [
        SizedBox(height: theme.spacingXl),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacingXl),
            // The hint shows only while nothing has happened yet; once a
            // live partial or a segment exists, that card is the signal.
            // Lines not flying to the Inbox (scheduled ones) fade with the
            // rest of the screen; the flying ones leave as their flights.
            child: FadeTransition(
              opacity: _controls,
              // The hint eases out as the first words arrive — requested
              // directly, "nicely animated out, not abruptly". Both lists
              // share a key, so submitting doesn't cross-fade them.
              child: AnimatedSwitcher(
                duration: VoiceModeTokens.hintExitDuration,
                switchInCurve: theme.curveDecelerate,
                switchOutCurve: theme.curveStandard,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(
                      begin: VoiceModeTokens.hintExitScale,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: quiet
                    ? VoiceCaptureHint(
                        key: const ValueKey('hint'),
                        theme: theme,
                      )
                    : segments,
              ),
            ),
          ),
        ),
        AppDepthTransition(
          depth: _controls,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacingXl,
              0,
              theme.spacingXl,
              theme.spacingBottomClearance + pane + theme.spacingMd,
            ),
            child: state.status == VoiceCaptureStatus.unavailable
                ? VoiceCaptureUnavailableCard(theme: theme)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
