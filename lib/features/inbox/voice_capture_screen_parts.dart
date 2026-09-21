import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import 'voice_capture_state.dart';

/// The private sub-widgets [VoiceCaptureScreen] composes — split into
/// this file purely to keep `voice_capture_screen.dart` under CLAUDE.md's
/// 200-line guidance, not because any of these are meant to be used
/// independently of that screen.

class VoiceCaptureHint extends StatelessWidget {
  const VoiceCaptureHint({super.key, required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Try saying',
            style: theme.textCaption.copyWith(color: theme.colorTextTertiary),
          ),
          SizedBox(height: theme.spacingSm),
          Text(
            '"Reply to Laura\'s email, book the flight, and submit my '
            'review. These are all high priority"',
            textAlign: TextAlign.center,
            style: theme.textTitle.copyWith(
              color: theme.colorTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceCaptureSegmentList extends StatelessWidget {
  const VoiceCaptureSegmentList({
    super.key,
    required this.theme,
    required this.segments,
  });

  final AmbleTheme theme;
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: theme.spacingLg),
        // Static label, not part of the scrolling list — each pill below
        // is a real task already created from a committed segment, not a
        // draft waiting on Submit. Requested directly: make it explicit
        // that tasks are created live, as the user speaks.
        Text(
          'Created as you speak',
          style: theme.textCaption.copyWith(color: theme.colorTextTertiary),
        ),
        SizedBox(height: theme.spacingSm),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: segments.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: theme.spacingMd),
            itemBuilder: (context, index) => Row(
              children: [
                Container(
                  width: theme.sizeTaskBadge,
                  height: theme.sizeTaskBadge,
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceField,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: theme.spacingMd),
                Expanded(
                  child: Text(
                    segments[index],
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VoiceCaptureStatusCard extends StatelessWidget {
  const VoiceCaptureStatusCard({
    super.key,
    required this.theme,
    required this.state,
  });

  final AmbleTheme theme;
  final VoiceCaptureState state;

  @override
  Widget build(BuildContext context) {
    final isPaused = state.status == VoiceCaptureStatus.paused;
    final title = isPaused ? 'Paused' : 'Listening';
    // Static regardless of `state.partialText` — requested directly: this
    // card's text must not change while the user is mid-sentence. The
    // live transcript still drives task creation (see
    // `VoiceCaptureCreatedAsYouSpeakLabel`/`VoiceCaptureSegmentList`), it
    // just isn't echoed back here any more.
    final subtitle = isPaused
        ? 'Resume to keep adding tasks, or save what you\'ve got.'
        : 'Say everything you need to get done';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPaused
            ? theme.colorSurfaceOverlay
            : theme.colorAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacingXs / 2),
            Text(
              subtitle,
              style: theme.textCaption.copyWith(
                color: theme.colorTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceCapturePauseResumeButton extends StatelessWidget {
  const VoiceCapturePauseResumeButton({
    super.key,
    required this.theme,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
  });

  final AmbleTheme theme;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    // Icon-swap-by-state on one button, matching AppMicButton's own
    // listening/idle icon swap (`app_mic_button.dart`) rather than two
    // separately-shown buttons — the mock shows the same slot holding
    // Pause while listening and Resume (circular arrow) once paused.
    return AppButton(
      icon: isPaused ? Icons.refresh_rounded : Icons.pause_rounded,
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.secondary,
      tooltip: isPaused ? 'Resume' : 'Pause',
      onPressed: isPaused ? onResume : onPause,
    );
  }
}
