import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/voice_mode_tokens.dart';
import 'package:amble/core/widgets/app_pane_morph.dart';
import 'package:amble/core/widgets/app_voice_glow.dart';
import 'package:flutter/material.dart';

/// Voice mode's entrance and exit: tap the mic pane and the glow rises while
/// the pane morphs into a toolbar; tap the toolbar to morph it back and let
/// the glow sink.
Widget voiceModeDemo(BuildContext context) => const _VoiceModeDemo();

class _VoiceModeDemo extends StatefulWidget {
  const _VoiceModeDemo();

  @override
  State<_VoiceModeDemo> createState() => _VoiceModeDemoState();
}

class _VoiceModeDemoState extends State<_VoiceModeDemo>
    with SingleTickerProviderStateMixin {
  late final _route = AnimationController(
    vsync: this,
    duration: VoiceModeTokens.enterDuration,
    reverseDuration: VoiceModeTokens.exitDuration,
  );
  late final _scrim = CurvedAnimation(
    parent: _route,
    curve: const Interval(0, VoiceModeTokens.scrimShare),
  );
  late final _rise = CurvedAnimation(
    parent: _route,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _scrim.dispose();
    _rise.dispose();
    _route.dispose();
    super.dispose();
  }

  void _toggle() =>
      _route.isForwardOrCompleted ? _route.reverse() : _route.forward();

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.dark;
    return ColoredBox(
      color: Theme.of(context).extension<AmbleTheme>()!.colorSurfaceBase,
      child: LayoutBuilder(
        builder: (context, box) {
          final pane = theme.sizeButtonMd + theme.spacingXs * 2;
          final bottom = box.maxHeight - theme.spacingBottomClearance;
          final target = Rect.fromLTRB(
            theme.spacingXl,
            bottom - pane,
            box.maxWidth - theme.spacingXl,
            bottom,
          );
          final origin = Rect.fromLTWH(
            box.maxWidth - theme.spacingMd * 2 - pane * 2,
            bottom - pane,
            pane,
            pane,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppVoiceGlow(theme: theme, scrim: _scrim, rise: _rise),
                ),
                Positioned.fill(
                  child: AppPaneMorph(
                    theme: theme,
                    animation: _route,
                    forwardSeconds: VoiceModeTokens.enterSeconds,
                    origin: origin,
                    target: target,
                    from: Icon(
                      Icons.mic_none_rounded,
                      color: theme.colorTextSecondary,
                    ),
                    child: Center(
                      child: Text('Voice toolbar', style: theme.textBody),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
