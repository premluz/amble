import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../core/widgets/app_voice_waveform.dart';
import 'voice_capture_provider.dart';
import 'voice_capture_screen_parts.dart';

/// Opens the full-screen "speak your tasks" flow — free speech, split
/// into separate tasks on each natural pause, all added to the Inbox
/// together on Submit. Requested directly, from two wireframes, as an
/// entry point "next to the plus" on the Inbox screen (see
/// `inbox_screen.dart`).
Future<void> showVoiceCaptureScreen(BuildContext context) {
  return pushFullScreenRoute<void>(
    context,
    (context) => const VoiceCaptureScreen(),
  );
}

/// Always renders [AmbleTheme.dark]'s own palette, regardless of the
/// app's current light/dark setting — confirmed directly, matching the
/// reference mock's dark, glowing background on both its listening and
/// paused states. A deliberate "focus mode" look, not a follow-the-
/// system-theme screen like the rest of the app.
///
/// Composes its content from `voice_capture_screen_parts.dart` (the hint,
/// the segment list, the status card, the pause/resume button) — split
/// out purely to keep this file under CLAUDE.md's 200-line guidance.
class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key, this.autoStartListening = true});

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
    final isPaused = state.status == VoiceCaptureStatus.paused;
    final isSubmitting = state.status == VoiceCaptureStatus.submitting;

    return Theme(
      data: ThemeData(useMaterial3: true, extensions: [theme]),
      child: Scaffold(
        backgroundColor: theme.colorSurfaceBase,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                theme.colorAccent.withValues(alpha: 0.28),
                theme.colorSurfaceBase,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacingMd),
                    child: AppButton(
                      icon: Icons.close_rounded,
                      shape: AppButtonShape.circle,
                      variant: AppButtonVariant.secondary,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacingXl),
                    // Hint shows only while genuinely nothing has
                    // happened yet — once the user has started speaking
                    // (a live partial exists) the in-progress card itself
                    // is the "something is happening" signal, so the
                    // hint gives way to it exactly like it already does
                    // once a segment commits.
                    child:
                        state.committedSegments.isEmpty &&
                            state.partialText.isEmpty
                        ? VoiceCaptureHint(theme: theme)
                        : VoiceCaptureSegmentList(
                            theme: theme,
                            segments: state.committedSegments,
                            partialText: state.partialText,
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingXl,
                    0,
                    theme.spacingXl,
                    theme.spacingLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VoiceCaptureStatusCard(theme: theme, state: state),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          VoiceCapturePauseResumeButton(
                            theme: theme,
                            isPaused: isPaused,
                            onPause: () =>
                                ref.read(voiceCaptureProvider.notifier).pause(),
                            onResume: () => ref
                                .read(voiceCaptureProvider.notifier)
                                .resume(),
                          ),
                          SizedBox(width: theme.spacingMd),
                          Expanded(
                            child: AppVoiceWaveform(
                              theme: theme,
                              level: state.soundLevel,
                              isActive:
                                  state.status == VoiceCaptureStatus.listening,
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppButton(
                            icon: Icons.arrow_upward_rounded,
                            shape: AppButtonShape.circle,
                            isLoading: isSubmitting,
                            tooltip: 'Submit',
                            // Disabled while zero segments have been
                            // captured yet — requested directly ("in
                            // listening mode before anything is said or
                            // created, it's disabled, not available").
                            onPressed: state.canSubmit && !isSubmitting
                                ? () async {
                                    await ref
                                        .read(voiceCaptureProvider.notifier)
                                        .submit();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
