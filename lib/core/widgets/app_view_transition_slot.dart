import 'package:flutter/material.dart';

class AppViewTransitionSlot extends StatelessWidget {
  const AppViewTransitionSlot({
    super.key,
    required this.child,
    required this.opacity,
    required this.interactive,
    required this.participating,
    required this.translation,
  });

  final Widget child;
  final double opacity;
  final bool interactive;
  final bool participating;
  final Offset translation;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !participating,
    child: TickerMode(
      enabled: participating,
      child: IgnorePointer(
        ignoring: !interactive,
        child: ExcludeSemantics(
          excluding: !interactive,
          child: ExcludeFocus(
            excluding: !interactive,
            child: FractionalTranslation(
              translation: translation,
              child: Opacity(opacity: opacity.clamp(0, 1), child: child),
            ),
          ),
        ),
      ),
    ),
  );
}
