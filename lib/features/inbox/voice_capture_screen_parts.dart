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
    this.partialText = '',
  });

  final AmbleTheme theme;

  /// Already-committed segments, oldest first — each one a real task.
  final List<String> segments;

  /// The segment currently being spoken, not yet committed — requested
  /// directly: as the user speaks, THIS card is what shows the words
  /// appearing word-by-word (the status card above stays static; see
  /// `VoiceCaptureStatusCard`). Rendered as one extra trailing row, one
  /// visual step behind a committed one (see `_VoiceCaptureSegmentRow
  /// .committed`) so it reads as still in progress. Empty (the default)
  /// renders nothing extra — no in-progress card until the user has
  /// actually started saying something.
  final String partialText;

  @override
  Widget build(BuildContext context) {
    final showPartial = partialText.isNotEmpty;
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: theme.spacingLg),
      itemCount: segments.length + (showPartial ? 1 : 0),
      separatorBuilder: (context, index) => SizedBox(height: theme.spacingMd),
      itemBuilder: (context, index) {
        final isPartialRow = index == segments.length;
        return _VoiceCaptureSegmentRow(
          theme: theme,
          text: isPartialRow ? partialText : segments[index],
          committed: !isPartialRow,
        );
      },
    );
  }
}

class _VoiceCaptureSegmentRow extends StatelessWidget {
  const _VoiceCaptureSegmentRow({
    required this.theme,
    required this.text,
    required this.committed,
  });

  final AmbleTheme theme;
  final String text;

  /// False only for the one trailing in-progress row — dims the badge and
  /// text so it visibly reads as "still being said," not yet a real task,
  /// distinct from every committed row above it.
  final bool committed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: theme.sizeTaskBadge,
          height: theme.sizeTaskBadge,
          decoration: BoxDecoration(
            color: theme.colorSurfaceField,
            shape: BoxShape.circle,
          ),
          child: committed
              ? null
              : Center(
                  child: SizedBox(
                    width: theme.spacingSm,
                    height: theme.spacingSm,
                    child: CircularProgressIndicator(
                      strokeWidth: theme.borderWidthHairline * 1.5,
                      color: theme.colorTextTertiary,
                    ),
                  ),
                ),
        ),
        SizedBox(width: theme.spacingMd),
        Expanded(
          child: Text(
            text,
            style: theme.textBody.copyWith(
              color: committed
                  ? theme.colorTextPrimary
                  : theme.colorTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    // Static — requested directly: this card's text never changes while
    // listening. The live, word-by-word transcript is shown in its OWN
    // task card instead, in `VoiceCaptureSegmentList` below, not echoed
    // here.
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
