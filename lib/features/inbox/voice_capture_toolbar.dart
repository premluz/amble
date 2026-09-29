import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/voice_mode_tokens.dart';
import '../../core/widgets/app_bottom_dock.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_voice_waveform.dart';

/// Where voice mode's two panes sit on a screen of [size], at the same
/// height and bottom clearance as every other toolbar dock: the close pane
/// alone at the right edge (where the Inbox's "+" sits), and the toolbar
/// pane filling the rest of the row, one dock gap to its left.
({Rect toolbar, Rect close}) voiceToolbarLayout(
  AmbleTheme theme,
  Size size,
  EdgeInsets viewPadding,
) {
  final height =
      appButtonHeightFor(theme, AppButtonSize.md) + theme.spacingXs * 2;
  final bottom =
      size.height - viewPadding.bottom - theme.spacingBottomClearance;
  final close = Rect.fromLTWH(
    size.width - theme.spacingMd - height,
    bottom - height,
    height,
    height,
  );
  return (
    toolbar: Rect.fromLTRB(
      theme.spacingXl,
      bottom - height,
      close.left - theme.spacingSm,
      bottom,
    ),
    close: close,
  );
}

/// Voice mode's toolbar contents, shown inside its glass pane: pause /
/// resume, the live waveform, and submit.
class VoiceCaptureToolbar extends StatelessWidget {
  const VoiceCaptureToolbar({
    super.key,
    required this.theme,
    required this.isPaused,
    required this.isListening,
    required this.isSubmitting,
    required this.soundLevel,
    required this.onPause,
    required this.onResume,
    required this.onSubmit,
  });

  final AmbleTheme theme;
  final bool isPaused;
  final bool isListening;
  final bool isSubmitting;
  final double soundLevel;
  final VoidCallback onPause;
  final VoidCallback onResume;

  /// Null while there is nothing to submit yet.
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(theme.spacingXs),
      child: Row(
        children: [
          // One slot, icon swapped by state: Pause while listening, Resume
          // (circular arrow) once paused.
          AppDockIconButton(
            theme: theme,
            icon: isPaused ? Icons.refresh_rounded : Icons.pause_rounded,
            tooltip: isPaused ? 'Resume' : 'Pause',
            selected: false,
            onTap: isPaused ? onResume : onPause,
          ),
          SizedBox(width: theme.spacingMd),
          Expanded(
            child: AppVoiceWaveform(
              theme: theme,
              level: soundLevel,
              isActive: isListening,
              // Keys rise in once the pane has stretched open.
              entranceDelay: VoiceModeTokens.keysDelay,
            ),
          ),
          SizedBox(width: theme.spacingMd),
          AppButton(
            icon: Icons.arrow_upward_rounded,
            shape: AppButtonShape.circle,
            isLoading: isSubmitting,
            tooltip: 'Submit',
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}
