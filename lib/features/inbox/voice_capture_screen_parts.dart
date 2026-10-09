import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../core/tokens/voice_mode_tokens.dart';
import 'task_list_row.dart';
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
            '“Plan holidays”',
            textAlign: TextAlign.center,
            style: theme.textTitle.copyWith(
              color: theme.colorTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: theme.spacingSm),
          Text(
            'You can add multiple tasks at once.',
            textAlign: TextAlign.center,
            style: theme.textBody.copyWith(color: theme.colorTextSecondary),
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
    this.heroTagFor,
  });

  /// Once submitted, each line that became an Inbox task carries that task's
  /// flight tag, so it flies into its row as voice mode closes. Null (or a
  /// null tag) means the line simply recedes with the screen.
  final Object? Function(int index)? heroTagFor;

  final AmbleTheme theme;

  /// Already-committed segments, oldest first — each one a real task.
  final List<String> segments;

  /// The segment currently being spoken, not yet committed — requested
  /// directly: as the user speaks, THIS card is what shows the words
  /// appearing word-by-word. Rendered as one extra trailing row, one
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
        final row = _VoiceCaptureSegmentRow(
          // By position: the line being spoken keeps its row as it commits,
          // so its ring can recede instead of vanishing.
          key: ValueKey(index),
          theme: theme,
          text: isPartialRow ? partialText : segments[index],
          committed: !isPartialRow,
        );
        final tag = isPartialRow ? null : heroTagFor?.call(index);
        return tag == null
            ? row
            // The Inbox row it lands in supplies the flight's shuttle.
            : Hero(tag: tag, child: row);
      },
    );
  }
}

/// One spoken line, drawn as the same card as an Inbox task ([TaskListRow])
/// so it looks identical before, during and after its flight into the
/// Inbox. It has no label yet, so its pill is the unassigned tone. While the
/// line is still being spoken, a ring grows out of the pill and the accent
/// traces round it over the silence window; when the line is done the ring
/// recedes back into the pill.
class _VoiceCaptureSegmentRow extends StatelessWidget {
  const _VoiceCaptureSegmentRow({
    super.key,
    required this.theme,
    required this.text,
    required this.committed,
  });

  final AmbleTheme theme;
  final String text;

  /// False for the in-progress (still being spoken) line.
  final bool committed;

  @override
  Widget build(BuildContext context) {
    final pillColor = TaskStateTokens.unlabeledFill(theme);
    // Begins at 0: a line appearing mid-speech grows its ring in, and one
    // that is already done when first built has none.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: committed ? 0 : 1),
      duration: committed
          ? VoiceModeTokens.pendingRingRecedeDuration
          : VoiceModeTokens.pendingRingGrowDuration,
      curve: committed ? theme.curveStandard : theme.curveDecelerate,
      builder: (context, presence, _) {
        if (committed) {
          return TaskListRow(
            theme: theme,
            title: text,
            pillColor: pillColor,
            pendingProgress: presence > 0 ? 1 : null,
            pendingPresence: presence,
          );
        }
        // Restarts with every new word: the silence gap is measured from
        // the last recognised speech (see
        // `VoiceCapture._restartSilenceTimer`).
        return TweenAnimationBuilder<double>(
          key: ValueKey(text),
          tween: Tween(begin: 0, end: 1),
          duration: voiceCaptureSilenceGap,
          builder: (context, progress, _) => TaskListRow(
            theme: theme,
            title: text,
            pillColor: pillColor,
            titleColor: theme.colorTextSecondary,
            pendingProgress: progress,
            pendingPresence: presence,
          ),
        );
      },
    );
  }
}

/// Shown only when listening can't start — requested directly: the
/// Listening / Paused card is gone (the toolbar's own state says that), but
/// a denied microphone still needs saying, with what to do about it.
class VoiceCaptureUnavailableCard extends StatelessWidget {
  const VoiceCaptureUnavailableCard({super.key, required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceOverlay,
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Can\'t listen',
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: theme.spacingXs / 2),
            Text(
              'Allow microphone and speech recognition in Settings, then tap '
              'Resume.',
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
