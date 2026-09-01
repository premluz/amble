import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A circular, icon-only adaptive mic button — same shape as [AppIconButton]
/// but with a second visual state for "actively listening," since a mic
/// button (unlike a plain icon button) has to show the user dictation is
/// live. Cupertino on iOS, Material elsewhere; screens never reach for
/// `CupertinoButton`/`FloatingActionButton` directly, per
/// docs/CONSTITUTION.md design principle 4.
class AppMicButton extends StatelessWidget {
  const AppMicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  /// True while dictation is actively capturing speech — swaps the icon
  /// (mic → stop) and the fill color to [AmbleTheme.colorTaskAlert], the
  /// same "notable, distinct from ordinary chrome" token already used for
  /// Quick Capture's own recurrence-token highlight, so a listening mic
  /// reads as a live, attention-worthy state rather than just another
  /// pressed button.
  final bool isListening;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final size = theme.spacingXl * 1.5;

    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isListening ? theme.colorTaskAlert : theme.colorAccent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
        color: theme.colorSurfacePrimary,
      ),
    );

    if (isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: button,
      );
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: button,
      ),
    );
  }
}
